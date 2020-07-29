//
//  QNDnsPrefetcher.m
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNDnsPrefetcher.h"
#import "QNInetAddress.h"
#import "QNDnsCacheInfo.h"
#import "QNConfig.h"
#import "QNDnsCacheFile.h"
#import "QNUpToken.h"
#import "QNUtils.h"
#import "QNAsyncRun.h"
#import "QNFixedZone.h"
#import "QNAutoZone.h"
#import <HappyDNS/HappyDNS.h>

//MARK: -- HappyDNS 适配
@interface QNRecord(DNS)<QNInetAddressDelegate>
@end
@implementation QNRecord(DNS)
- (NSString *)hostValue{
    return nil;
}
- (NSString *)ipValue{
    return self.value;
}
- (NSNumber *)ttlValue{
    return @(self.ttl);
}
- (NSNumber *)timestampValue{
    return @(self.timeStamp);
}
@end

@interface QNDnsManager(DNS)<QNDnsDelegate>
@end
@implementation QNDnsManager(DNS)

- (NSArray<id<QNInetAddressDelegate>> *)lookup:(NSString *)host{

    return [self queryRecords:host];
}

@end


//MARK: -- DNS Prefetcher
@interface QNDnsPrefetcher()

/// 是否正在预取，正在预取会直接取消新的预取操作请求
@property(atomic, assign)BOOL isPrefetching;
/// 获取AutoZone时的同步锁
@property(nonatomic, strong)dispatch_semaphore_t getAutoZoneSemaphore;
/// DNS信息本地缓存key
@property(nonatomic, strong)QNDnsCacheInfo *dnsCacheInfo;
/// happy的dns解析对象列表，会使用多个dns解析对象 包括系统解析
@property(nonatomic, strong)QNDnsManager * httpDns;
/// 缓存DNS解析结果
@property(nonatomic, strong)NSMutableDictionary <NSString *, NSArray<QNInetAddress *>*> *addressDictionary;

@end

@implementation QNDnsPrefetcher

+ (instancetype)shared{
    static QNDnsPrefetcher *prefetcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefetcher = [[QNDnsPrefetcher alloc] init];
    });
    return prefetcher;
}

- (instancetype)init{
    if (self = [super init]) {
        _isPrefetching = NO;
    }
    return self;
}

//MARK: -- uploadManager初始化时，加载本地缓存到内存
/// 同步本地预取缓存 如果存在且满足使用返回false，反之为true
- (BOOL)recoverCache{
    NSLog(@"== recoverCache");
    id <QNRecorderDelegate> recorder = nil;
    
    NSError *error;
    recorder = [QNDnsCacheFile dnsCacheFile:kQNGlobalConfiguration.dnscacheDir
                                      error:&error];
    if (error) {
        return YES;
    }
    
    NSData *data = [recorder get:[QNIP local]];
    if (!data) {
        return YES;
    }
    
    QNDnsCacheInfo *cacheInfo = [QNDnsCacheInfo dnsCacheInfo:data];
    if (!cacheInfo) {
        return YES;
    }
    
    NSString *localIp = [QNIP local];

    if (!localIp || localIp.length == 0) {
        return YES;
    }
    
    if (![cacheInfo.localIp isEqualToString:localIp]) {
        return YES;
    }
    
    [self setDnsCacheInfo:cacheInfo];
    
    return [self recoverDnsCache:cacheInfo.info];
}
/// 本地缓存读取失败后，加载本地域名，预取DNS解析信息
- (void)localFetch{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    
    NSLog(@"== localFetch");
    [self preFetchHosts:[self getLocalPreHost]];
    [self recorderDnsCache];
    [self endPreFetch];
}
//MARK: -- 检测并预取
/// 根据token检测Dns缓存信息时效，无效则预取。 完成预取操作返回YES，反之返回NO
- (void)checkAndPrefetchDnsIfNeed:(QNZone *)currentZone token:(NSString *)token{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    [self preFetchHosts:[self getCurrentZoneHosts:currentZone token:token]];
    [self recorderDnsCache];
    [self endPreFetch];
}
/// 检测已预取dns是否还有效，无效则重新预取
- (void)checkWhetherCachedDnsValid{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    [self preFetchHosts:[self.addressDictionary allKeys]];
    [self recorderDnsCache];
    [self endPreFetch];
}

//MARK: -- 强制无效缓存
// 无效缓存，会根据inetAddress的host，无效host对应的ip缓存
- (void)invalidInetAdress:(id <QNInetAddressDelegate>)inetAddress{
    NSArray *inetAddressList = self.addressDictionary[inetAddress.hostValue];
    NSMutableArray *inetAddressListNew = [NSMutableArray array];
    for (id <QNInetAddressDelegate> inetAddressP in inetAddressList) {
        if (![inetAddress.ipValue isEqualToString:inetAddressP.ipValue]) {
            [inetAddressListNew addObject:inetAddressP];
        }
    }
    [self.addressDictionary setObject:[inetAddressListNew copy] forKey:inetAddress.hostValue];
}

//MARK: -- 读取缓存的DNS信息
/// 根据host从缓存中读取DNS信息
- (NSArray <id <QNInetAddressDelegate> > *)getInetAddressByHost:(NSString *)host{

    if ([self isDnsOpen] == NO) {
        return nil;
    }
    
    NSArray <QNInetAddress *> *addressList = self.addressDictionary[host];
    if (![addressList.firstObject isValid]) {
        QNAsyncRun(^{
            [[QNTransactionManager shared] setDnsCheckWhetherCachedValidTransactionAction];
        });
    }
    return addressList;
}

//MARK: --
//MARK: -- 根据dns预取
- (BOOL)prepareToPreFetch{
    if ([self isDnsOpen] == NO) {
        return NO;
    }
    
    if (self.isPrefetching == YES) {
        return NO;
    }
    
    NSString *localIp = [QNIP local];
    if (localIp == nil ||
        (self.dnsCacheInfo && ![localIp isEqualToString:self.dnsCacheInfo.localIp])) {

        [self clearPreHosts];
    }
    
    self.isPrefetching = YES;
    return YES;
}

- (void)endPreFetch{
    self.isPrefetching = NO;
}

- (void)preFetchHosts:(NSArray <NSString *> *)fetchHosts{
    
    self.httpDns.defaultTtl = kQNGlobalConfiguration.dnsCacheTime;
    
    NSArray *nextFetchHosts = fetchHosts;
    
    nextFetchHosts = [self preFetchHosts:nextFetchHosts
                                     dns:kQNGlobalConfiguration.dns];
    
    nextFetchHosts = [self preFetchHosts:nextFetchHosts
                                     dns:self.httpDns];
}

- (NSArray *)preFetchHosts:(NSArray <NSString *> *)preHosts
                       dns:(id <QNDnsDelegate>)dns{

    if (!preHosts || preHosts.count == 0) {
        return nil;
    }
    
    if (!dns) {
        return [preHosts copy];
    }
    
    NSMutableArray *failHosts = [NSMutableArray array];
    for (NSString *host in preHosts) {
        int rePreNum = 0;
        BOOL isSuccess = NO;
        
        while (rePreNum < kQNGlobalConfiguration.dnsRepreHostNum) {
            if ([self preFetchHost:host dns:dns]) {
                isSuccess = YES;
                break;
            }
        }
        
        if (!isSuccess) {
            [failHosts addObject:host];
        }
    }
    return [failHosts copy];
}

- (BOOL)preFetchHost:(NSString *)preHost
                 dns:(id <QNDnsDelegate>)dns{
    
    if (!preHost || preHost.length == 0) {
        return NO;
    }
    
    NSArray<QNInetAddress *>* preAddressList = self.addressDictionary[preHost];
    if (preAddressList && [preAddressList.firstObject isValid]) {
        return YES;
    }
    
    NSArray <id <QNInetAddressDelegate> > * addressList = [dns lookup:preHost];
    if (addressList && addressList.count > 0) {
        NSMutableArray *addressListP = [NSMutableArray array];
        for (id <QNInetAddressDelegate>inetAddress in addressList) {
            QNInetAddress *address = [QNInetAddress inetAddress:inetAddress];
            if (address) {
                address.hostValue = preHost;
                if (!address.ttlValue) {
                    address.ttlValue = @(kQNDefaultDnsCacheTime);
                }
                if (!address.timestampValue) {
                    address.timestampValue = @([[NSDate date] timeIntervalSince1970]);
                }
                [addressListP addObject:address];
            }
        }
        self.addressDictionary[preHost] = [addressListP copy];
        return YES;
    } else {
        return NO;
    }
}

//MARK: -- 加载和存储缓存信息
- (BOOL)recoverDnsCache:(NSDictionary *)dataDic{
    if (dataDic == nil) {
        return NO;
    }
    
    NSMutableDictionary *newAddressDictionary = [NSMutableDictionary dictionary];
    for (NSString *key in dataDic.allKeys) {
        NSArray *ips = dataDic[key];
        if ([ips isKindOfClass:[NSArray class]]) {
            
            NSMutableArray <QNInetAddress *> * addressList = [NSMutableArray array];
            
            for (NSDictionary *ipInfo in ips) {
                if ([ipInfo isKindOfClass:[NSDictionary class]]) {
                    QNInetAddress *address = [QNInetAddress inetAddress:ipInfo];
                    if (address) {
                        [addressList addObject:address];
                    }
                }
            }
            
            if (addressList.count > 0) {
                newAddressDictionary[key] = [addressList copy];
            }
        }
    }
    self.addressDictionary = newAddressDictionary;
    
    NSLog(@"== recoverDnsCache");
    return NO;
}

- (BOOL)recorderDnsCache{
    NSTimeInterval currentTime = [QNUtils currentTimestamp];
    NSString *localIp = [QNIP local];
    
    if (localIp == nil || localIp.length == 0) {
        return NO;
    }

    NSError *error;
    id <QNRecorderDelegate> recorder = [QNDnsCacheFile dnsCacheFile:kQNGlobalConfiguration.dnscacheDir
                                                             error:&error];
    if (error) {
        return NO;
    }
    
    NSMutableDictionary *addressInfo = [NSMutableDictionary dictionary];
    for (NSString *key in self.addressDictionary.allKeys) {
       
        NSArray *addressModelList = self.addressDictionary[key];
        NSMutableArray * addressDicList = [NSMutableArray array];
        for (QNInetAddress *ipInfo in addressModelList) {
           
            NSDictionary *addressDic = [ipInfo toDictionary];
            if (addressDic) {
                [addressDicList addObject:addressDic];
            }
        }
       
        if (addressDicList.count > 0) {
            addressInfo[key] = addressDicList;
        }
    }
   
    QNDnsCacheInfo *cacheInfo = [QNDnsCacheInfo dnsCacheInfo:[NSString stringWithFormat:@"%.0lf",currentTime]
                                                     localIp:localIp
                                                        info:addressInfo];
    
    NSData *cacheData = [cacheInfo jsonData];
    if (!cacheData) {
        return NO;
    }
    [self setDnsCacheInfo:cacheInfo];
    [recorder set:localIp data:cacheData];
    return true;
}

- (void)clearPreHosts{
    [self.addressDictionary removeAllObjects];
}


//MARK: -- 获取预取hosts
- (NSArray <NSString *> *)getLocalPreHost{

    NSMutableArray *localHosts = [NSMutableArray array];
    
    NSArray *fixedHosts = [self getFixedZoneHosts];
    [localHosts addObjectsFromArray:fixedHosts];
    
    NSString *ucHost = kQNPreQueryHost;
    [localHosts addObject:ucHost];
    
    return [localHosts copy];
}

- (NSArray <NSString *> *)getAllPreHost:(QNZone *)currentZone
                                  token:(NSString *)token{
    
    NSMutableSet *set = [NSMutableSet set];
    NSMutableArray *fetchHosts = [NSMutableArray array];
    
    NSArray *fixedHosts = [self getFixedZoneHosts];
    [fetchHosts addObjectsFromArray:fixedHosts];
    
    NSArray *autoHosts = [self getCurrentZoneHosts:currentZone token:token];
    [fetchHosts addObjectsFromArray:autoHosts];
    
    NSString *ucHost = kQNPreQueryHost;
    [fetchHosts addObject:ucHost];
    
    NSArray *cacheHost = [self getCacheHosts];
    [fetchHosts addObjectsFromArray:cacheHost];
    
    NSMutableArray *fetchHostsFiltered = [NSMutableArray array];
    for (NSString *host in fetchHosts) {
        NSInteger countBeforeAdd = set.count;
        [set addObject:host];
        NSInteger countAfterAdd = set.count;
        if (countBeforeAdd < countAfterAdd) {
            [fetchHostsFiltered addObject:host];
        }
    }
    return [fetchHostsFiltered copy];
}

- (NSArray <NSString *> *)getCurrentZoneHosts:(QNZone *)currentZone
                                        token:(NSString *)token{
    if (!currentZone || !token) {
        return nil;
    }
    [currentZone preQuery:[QNUpToken parse:token] on:^(int code, QNHttpResponseInfo *httpResponseInfo) {
        dispatch_semaphore_signal(self.semaphore);
    }];
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    QNZonesInfo *autoZonesInfo = [currentZone getZonesInfoWithToken:[QNUpToken parse:token]];
    NSMutableArray *autoHosts = [NSMutableArray array];
    NSArray *zoneInfoList = autoZonesInfo.zonesInfo;
    for (QNZoneInfo *info in zoneInfoList) {
        for (NSString *host in info.upDomainsList) {
            [autoHosts addObject:host];
        }
    }
    return [autoHosts copy];
}

- (NSArray <NSString *> *)getFixedZoneHosts{
    NSArray <QNFixedZone *> *fixedZones = [QNFixedZone localsZoneInfo];
    NSMutableArray *localHosts = [NSMutableArray array];
    for (QNFixedZone *fixZone in fixedZones) {
        QNZonesInfo *zonesInfo = [fixZone getZonesInfoWithToken:nil];
        for (QNZoneInfo *zoneInfo in zonesInfo.zonesInfo) {
            for (NSString *host in zoneInfo.upDomainsList) {
                [localHosts addObject:host];
            }
        }
    }
    return [localHosts copy];
}

- (NSArray <NSString *> *)getCacheHosts{
    return self.addressDictionary.allKeys;
}


//MARK: --
- (BOOL)isDnsOpen{
    return [kQNGlobalConfiguration isDnsOpen];
}

- (NSMutableDictionary<NSString *,NSArray<QNInetAddress *> *> *)addressDictionary{
    if (_addressDictionary == nil) {
        _addressDictionary = [NSMutableDictionary dictionary];
    }
    return _addressDictionary;
}

- (dispatch_semaphore_t)semaphore{
    if (_getAutoZoneSemaphore == NULL) {
        _getAutoZoneSemaphore = dispatch_semaphore_create(0);
    }
    return _getAutoZoneSemaphore;
}

- (QNDnsManager *)httpDns{
    if (_httpDns == nil) {
        QNResolver *systemDnsresolver = [QNResolver systemResolver];
        QNDnspodFree *dnspodFree = [[QNDnspodFree alloc] init];
        QNDnsManager *httpDns = [[QNDnsManager alloc] init:@[systemDnsresolver, dnspodFree]
                                               networkInfo:nil];
        _httpDns = httpDns;
    }
    return _httpDns;
}
@end


//MARK: -- DNS 事务
@implementation QNTransactionManager(Dns)
#define kQNLoadLocalDnstransactionName @"QNLoadLocalDnstransaction"
#define kQNDnsCheckAndPrefetchtransactionName @"QNDnsCheckAndPrefetchtransactionName"

- (void)addDnsLocalLoadTransaction{
    
    if ([kQNDnsPrefetcher isDnsOpen] == NO) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        QNTransaction *transaction = [QNTransaction transaction:kQNLoadLocalDnstransactionName after:0 action:^{
            
            [kQNDnsPrefetcher recoverCache];
            [kQNDnsPrefetcher localFetch];
        }];
        [[QNTransactionManager shared] addTransaction:transaction];
    });
}

- (BOOL)addDnsCheckAndPrefetchTransaction:(QNZone *)currentZone token:(NSString *)token{
    if (!token) {
        return NO;
    }
    
    if ([kQNDnsPrefetcher isDnsOpen] == NO) {
        return NO;
    }
    
    BOOL ret = NO;
    @synchronized (kQNDnsPrefetcher) {
        
        QNTransactionManager *transactionManager = [QNTransactionManager shared];
        
        if (![transactionManager existtransactionsForName:token]) {
            QNTransaction *transaction = [QNTransaction transaction:token after:0 action:^{
               
                [kQNDnsPrefetcher checkAndPrefetchDnsIfNeed:currentZone token:token];
            }];
            [transactionManager addTransaction:transaction];
            
            ret = YES;
        }
    }
    return ret;
}

- (void)setDnsCheckWhetherCachedValidTransactionAction{

    if ([kQNDnsPrefetcher isDnsOpen] == NO) {
        return;
    }
    
    @synchronized (kQNDnsPrefetcher) {
        
        QNTransactionManager *transactionManager = [QNTransactionManager shared];
        QNTransaction *transaction = [transactionManager transactionsForName:kQNDnsCheckAndPrefetchtransactionName].firstObject;
        
        if (!transaction) {
            
            QNTransaction *transaction = [QNTransaction timeTransaction:kQNDnsCheckAndPrefetchtransactionName
                                                                  after:10
                                                               interval:120
                                                                 action:^{
                [kQNDnsPrefetcher checkWhetherCachedDnsValid];
            }];
            [transactionManager addTransaction:transaction];
        } else {
            [transactionManager performTransaction:transaction];
        }
    }
}

@end
