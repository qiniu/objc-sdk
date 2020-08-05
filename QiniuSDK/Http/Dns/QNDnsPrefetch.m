//
//  QNDnsPrefetch.m
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//


#import "QNDnsPrefetch.h"
#import "QNInetAddress.h"
#import "QNDnsCacheInfo.h"

#import "QNConfig.h"
#import "QNDnsCacheFile.h"
#import "QNUtils.h"
#import "QNAsyncRun.h"
#import "QNFixedZone.h"
#import "QNAutoZone.h"
#import <HappyDNS/HappyDNS.h>


//MARK: -- 缓存模型
@interface QNDnsNetworkAddress : NSObject<QNIDnsNetworkAddress>

@property(nonatomic,   copy)NSString *hostValue;
@property(nonatomic,   copy)NSString *ipValue;
@property(nonatomic, strong)NSNumber *ttlValue;
@property(nonatomic,   copy)NSString *sourceValue;
@property(nonatomic, strong)NSNumber *timestampValue;

/// 构造方法 addressData为json String / Dictionary / Data / 遵循 QNIDnsNetworkAddress的实例
+ (instancetype)inetAddress:(id)addressInfo;

/// 是否有效，根据时间戳判断
- (BOOL)isValid;

/// 对象转json
- (NSString *)toJsonInfo;

/// 对象转字典
- (NSDictionary *)toDictionary;

@end
@implementation QNDnsNetworkAddress

+ (instancetype)inetAddress:(id)addressInfo{
    
    NSDictionary *addressDic = nil;
    if ([addressInfo isKindOfClass:[NSDictionary class]]) {
        addressDic = (NSDictionary *)addressInfo;
    } else if ([addressInfo isKindOfClass:[NSString class]]){
        NSData *data = [(NSString *)addressInfo dataUsingEncoding:NSUTF8StringEncoding];
        addressDic = [NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableLeaves
                                                       error:nil];
    } else if ([addressInfo isKindOfClass:[NSData class]]) {
        addressDic = [NSJSONSerialization JSONObjectWithData:(NSData *)addressInfo
                                                     options:NSJSONReadingMutableLeaves
                                                       error:nil];
    } else if ([addressInfo conformsToProtocol:@protocol(QNIDnsNetworkAddress)]){
        id <QNIDnsNetworkAddress> address = (id <QNIDnsNetworkAddress> )addressInfo;
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        if ([address respondsToSelector:@selector(hostValue)] && [address hostValue]) {
            dic[@"hostValue"] = [address hostValue];
        }
        if ([address respondsToSelector:@selector(ipValue)] && [address ipValue]) {
            dic[@"ipValue"] = [address ipValue];
        }
        if ([address respondsToSelector:@selector(ttlValue)] && [address ttlValue]) {
            dic[@"ttlValue"] = [address ttlValue];
        }
        if ([address respondsToSelector:@selector(source)] && [address sourceValue]) {
            dic[@"sourceValue"] = [address sourceValue];
        }
        if ([address respondsToSelector:@selector(timestampValue)] && [address timestampValue]) {
            dic[@"timestampValue"] = [address timestampValue];
        }
        addressDic = [dic copy];
    }
    
    if (addressDic) {
        QNDnsNetworkAddress *address = [[QNDnsNetworkAddress alloc] init];
        [address setValuesForKeysWithDictionary:addressDic];
        return address;
    } else {
        return nil;
    }
}

- (BOOL)isValid{
    if (!self.timestampValue || !self.ipValue || self.ipValue.length == 0) {
        return NO;
    }
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    return currentTimestamp > self.timestampValue.doubleValue + self.ttlValue.doubleValue;
}

- (NSString *)toJsonInfo{
    NSString *defaultString = @"{}";
    NSDictionary *infoDic = [self toDictionary];
    if (!infoDic) {
        return defaultString;
    }
    
    NSData *infoData = [NSJSONSerialization dataWithJSONObject:infoDic
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    if (!infoData) {
        return defaultString;
    }
    
    NSString *infoStr = [[NSString alloc] initWithData:infoData encoding:NSUTF8StringEncoding];
    if (!infoStr) {
        return defaultString;
    } else {
        return infoStr;
    }
}

- (NSDictionary *)toDictionary{
    return [self dictionaryWithValuesForKeys:@[@"ipValue", @"hostValue", @"ttlValue", @"sourceValue", @"timestampValue"]];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{}

@end


//MARK: -- HappyDNS 适配
@interface QNRecord(DNS)<QNIDnsNetworkAddress>
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
- (NSString *)sourceValue{
    if (self.source == QNRecordSourceSystem) {
        return @"system";
    } else if (self.source == QNRecordSourceDnspodFree || self.source == QNRecordSourceDnspodEnterprise) {
        return @"httpdns";
    } else {
        return @"none";
    }
}
@end

@interface QNDnsManager(DNS)<QNDnsDelegate>
@end
@implementation QNDnsManager(DNS)

- (NSArray<id<QNIDnsNetworkAddress>> *)lookup:(NSString *)host{

    return [self queryRecords:host];
}

@end


//MARK: -- DNS Prefetcher
@interface QNDnsPrefetch()

// 最近一次预取错误信息
@property(nonatomic,  copy)NSString *lastPrefetchedErrorMessage;
/// 是否正在预取，正在预取会直接取消新的预取操作请求
@property(atomic, assign)BOOL isPrefetching;
/// 获取AutoZone时的同步锁
@property(nonatomic, strong)dispatch_semaphore_t getAutoZoneSemaphore;
/// DNS信息本地缓存key
@property(nonatomic, strong)QNDnsCacheInfo *dnsCacheInfo;
/// happy的dns解析对象列表，会使用多个dns解析对象 包括系统解析
@property(nonatomic, strong)QNDnsManager * httpDns;
/// 缓存DNS解析结果
@property(nonatomic, strong)NSMutableDictionary <NSString *, NSArray<QNDnsNetworkAddress *>*> *addressDictionary;

@end

@implementation QNDnsPrefetch

+ (instancetype)shared{
    static QNDnsPrefetch *prefetcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefetcher = [[QNDnsPrefetch alloc] init];
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
    id <QNRecorderDelegate> recorder = nil;
    
    NSError *error;
    recorder = [QNDnsCacheFile dnsCacheFile:kQNGlobalConfiguration.dnsCacheDir
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

    if (!localIp || localIp.length == 0 || ![cacheInfo.localIp isEqualToString:localIp]) {
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
    
    [self preFetchHosts:[self getLocalPreHost]];
    [self recorderDnsCache];
    [self endPreFetch];
}
//MARK: -- 检测并预取
/// 根据token检测Dns缓存信息时效，无效则预取。 完成预取操作返回YES，反之返回NO
- (void)checkAndPrefetchDnsIfNeed:(QNZone *)currentZone token:(QNUpToken *)token{
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
- (void)invalidInetAdress:(id <QNIDnsNetworkAddress>)inetAddress{
    NSArray *inetAddressList = self.addressDictionary[inetAddress.hostValue];
    NSMutableArray *inetAddressListNew = [NSMutableArray array];
    for (id <QNIDnsNetworkAddress> inetAddressP in inetAddressList) {
        if (![inetAddress.ipValue isEqualToString:inetAddressP.ipValue]) {
            [inetAddressListNew addObject:inetAddressP];
        }
    }
    [self.addressDictionary setObject:[inetAddressListNew copy] forKey:inetAddress.hostValue];
}

//MARK: -- 读取缓存的DNS信息
/// 根据host从缓存中读取DNS信息
- (NSArray <id <QNIDnsNetworkAddress> > *)getInetAddressByHost:(NSString *)host{

    if ([self isDnsOpen] == NO) {
        return nil;
    }
    
    NSArray <QNDnsNetworkAddress *> *addressList = self.addressDictionary[host];
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
    
    self.lastPrefetchedErrorMessage = nil;
    
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
            rePreNum += 1;
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
    
    NSArray<QNDnsNetworkAddress *>* preAddressList = self.addressDictionary[preHost];
    if (preAddressList && [preAddressList.firstObject isValid]) {
        return YES;
    }
    
    NSArray <id <QNIDnsNetworkAddress> > * addressList = [dns lookup:preHost];
    if (addressList && addressList.count > 0) {
        NSMutableArray *addressListP = [NSMutableArray array];
        for (id <QNIDnsNetworkAddress>inetAddress in addressList) {
            QNDnsNetworkAddress *address = [QNDnsNetworkAddress inetAddress:inetAddress];
            if (address) {
                if (dns == kQNGlobalConfiguration.dns) {
                    address.sourceValue = @"customized";
                }
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
            
            NSMutableArray <QNDnsNetworkAddress *> * addressList = [NSMutableArray array];
            
            for (NSDictionary *ipInfo in ips) {
                if ([ipInfo isKindOfClass:[NSDictionary class]]) {
                    QNDnsNetworkAddress *address = [QNDnsNetworkAddress inetAddress:ipInfo];
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
    
    return NO;
}

- (BOOL)recorderDnsCache{
    NSTimeInterval currentTime = [QNUtils currentTimestamp];
    NSString *localIp = [QNIP local];
    
    if (localIp == nil || localIp.length == 0) {
        return NO;
    }

    NSError *error;
    id <QNRecorderDelegate> recorder = [QNDnsCacheFile dnsCacheFile:kQNGlobalConfiguration.dnsCacheDir
                                                             error:&error];
    if (error) {
        return NO;
    }
    
    NSMutableDictionary *addressInfo = [NSMutableDictionary dictionary];
    for (NSString *key in self.addressDictionary.allKeys) {
       
        NSArray *addressModelList = self.addressDictionary[key];
        NSMutableArray * addressDicList = [NSMutableArray array];

        for (QNDnsNetworkAddress *ipInfo in addressModelList) {
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
    
    [localHosts addObject:kQNPreQueryHost00];
    [localHosts addObject:kQNPreQueryHost01];
    
    return [localHosts copy];
}

- (NSArray <NSString *> *)getAllPreHost:(QNZone *)currentZone
                                  token:(QNUpToken *)token{
    
    NSMutableSet *set = [NSMutableSet set];
    NSMutableArray *fetchHosts = [NSMutableArray array];
    
    NSArray *fixedHosts = [self getFixedZoneHosts];
    [fetchHosts addObjectsFromArray:fixedHosts];
    
    NSArray *autoHosts = [self getCurrentZoneHosts:currentZone token:token];
    [fetchHosts addObjectsFromArray:autoHosts];
    
    [fetchHosts addObject:kQNPreQueryHost00];
    [fetchHosts addObject:kQNPreQueryHost01];
    
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
                                        token:(QNUpToken *)token{
    if (!currentZone || !token || !token.token) {
        return nil;
    }
    [currentZone preQuery:token on:^(int code, QNResponseInfo *responseInfo, QNUploadRegionRequestMetrics *metrics) {
        dispatch_semaphore_signal(self.semaphore);
    }];
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    QNZonesInfo *autoZonesInfo = [currentZone getZonesInfoWithToken:token];
    NSMutableArray *autoHosts = [NSMutableArray array];
    NSArray *zoneInfoList = autoZonesInfo.zonesInfo;
    for (QNZoneInfo *info in zoneInfoList) {
        if (info.allHosts) {
            [autoHosts addObjectsFromArray:info.allHosts];
        }
    }
    return [autoHosts copy];
}

- (NSArray <NSString *> *)getFixedZoneHosts{
    NSMutableArray *localHosts = [NSMutableArray array];
    QNFixedZone *fixedZone = [QNFixedZone localsZoneInfo];
    QNZonesInfo *zonesInfo = [fixedZone getZonesInfoWithToken:nil];
    for (QNZoneInfo *zoneInfo in zonesInfo.zonesInfo) {
        if (zoneInfo.allHosts) {
            [localHosts addObjectsFromArray:zoneInfo.allHosts];
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

- (QNDnsCacheInfo *)dnsCacheInfo{
    if (_dnsCacheInfo == nil) {
        _dnsCacheInfo = [[QNDnsCacheInfo alloc] init];
    }
    return _dnsCacheInfo;
}
- (NSMutableDictionary<NSString *,NSArray<QNDnsNetworkAddress *> *> *)addressDictionary{
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
        
        __weak typeof(self)weakSelf = self;
        httpDns.queryErrorHandler = ^(NSError *error, NSString *host) {
            weakSelf.lastPrefetchedErrorMessage = [error localizedDescription];
        };
        _httpDns = httpDns;
    }
    return _httpDns;
}
@end


//MARK: -- DNS 事务
@implementation QNTransactionManager(Dns)
#define kQNLoadLocalDnsTransactionName @"QNLoadLocalDnsTransaction"
#define kQNDnsCheckAndPrefetchTransactionName @"QNDnsCheckAndPrefetchTransactionName"

- (void)addDnsLocalLoadTransaction{
    
    if ([kQNDnsPrefetch isDnsOpen] == NO) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        QNTransaction *transaction = [QNTransaction transaction:kQNLoadLocalDnsTransactionName after:0 action:^{
            
            [kQNDnsPrefetch recoverCache];
            [kQNDnsPrefetch localFetch];
        }];
        [[QNTransactionManager shared] addTransaction:transaction];
    });
}

- (BOOL)addDnsCheckAndPrefetchTransaction:(QNZone *)currentZone token:(QNUpToken *)token{
    if (!token) {
        return NO;
    }
    
    if ([kQNDnsPrefetch isDnsOpen] == NO) {
        return NO;
    }
    
    BOOL ret = NO;
    @synchronized (kQNDnsPrefetch) {
        
        QNTransactionManager *transactionManager = [QNTransactionManager shared];
        
        if (![transactionManager existTransactionsForName:token.token]) {
            QNTransaction *transaction = [QNTransaction transaction:token.token after:0 action:^{
               
                [kQNDnsPrefetch checkAndPrefetchDnsIfNeed:currentZone token:token];
            }];
            [transactionManager addTransaction:transaction];
            
            ret = YES;
        }
    }
    return ret;
}

- (void)setDnsCheckWhetherCachedValidTransactionAction{

    if ([kQNDnsPrefetch isDnsOpen] == NO) {
        return;
    }
    
    @synchronized (kQNDnsPrefetch) {
        
        QNTransactionManager *transactionManager = [QNTransactionManager shared];
        QNTransaction *transaction = [transactionManager transactionsForName:kQNDnsCheckAndPrefetchTransactionName].firstObject;
        
        if (!transaction) {
            
            QNTransaction *transaction = [QNTransaction timeTransaction:kQNDnsCheckAndPrefetchTransactionName
                                                                  after:10
                                                               interval:120
                                                                 action:^{
                [kQNDnsPrefetch checkWhetherCachedDnsValid];
            }];
            [transactionManager addTransaction:transaction];
        } else {
            [transactionManager performTransaction:transaction];
        }
    }
}

@end
