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
#import "QNZoneInfo.h"

#import "QNDefine.h"
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
        if ([address respondsToSelector:@selector(sourceValue)] && [address sourceValue]) {
            dic[@"sourceValue"] = [address sourceValue];
        } else {
            dic[@"sourceValue"] = kQNDnsSourceCustom;
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

/// 过了 ttl 时间则需要刷新
- (BOOL)needRefresh{
    if (!self.timestampValue || !self.ipValue || self.ipValue.length == 0) {
        return NO;
    }
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    return currentTimestamp > (self.timestampValue.doubleValue + self.ttlValue.doubleValue);
}

/// 只要在最大 ttl 时间内，即为有效
- (BOOL)isValid{
    if (!self.timestampValue || !self.ipValue || self.ipValue.length == 0) {
        return NO;
    }
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    return currentTimestamp < (self.timestampValue.doubleValue + kQNGlobalConfiguration.dnsCacheMaxTTL);
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
        return kQNDnsSourceSystem;
    } else if (self.source == QNRecordSourceDoh) {
        return [NSString stringWithFormat:@"%@<%@>", kQNDnsSourceDoh, self.server];
    } else if (self.source == QNRecordSourceUdp) {
        return [NSString stringWithFormat:@"%@<%@>", kQNDnsSourceUdp, self.server];
    } else if (self.source == QNRecordSourceDnspodEnterprise) {
        return kQNDnsSourceDnspod;
    } else if (self.ipValue == nil || self.ipValue.length == 0) {
        return kQNDnsSourceNone;
    } else {
        return kQNDnsSourceCustom;
    }
}
@end

@interface QNInternalDns : NSObject
@property(nonatomic, strong)id<QNDnsDelegate> dns;
@property(nonatomic, strong)id<QNResolverDelegate> resolver;
@end
@implementation QNInternalDns
+ (instancetype)dnsWithDns:(id<QNDnsDelegate>)dns {
    QNInternalDns *interDns = [[QNInternalDns alloc] init];
    interDns.dns = dns;
    return interDns;
}
+ (instancetype)dnsWithResolver:(id<QNResolverDelegate>)resolver {
    QNInternalDns *interDns = [[QNInternalDns alloc] init];
    interDns.resolver = resolver;
    return interDns;
}
- (NSArray < id <QNIDnsNetworkAddress> > *)lookup:(NSString *)host error:(NSError **)error {
    if (self.dns) {
        return [self.dns lookup:host];
    } else if (self.resolver) {
        NSArray <QNRecord *>* records = [self.resolver query:[[QNDomain alloc] init:host] networkInfo:nil error:error];
        return [self filterRecords:records];
    }
    return nil;
}
- (NSArray <QNRecord *>*)filterRecords:(NSArray <QNRecord *>*)records {
    NSMutableArray <QNRecord *> *newRecords = [NSMutableArray array];
    for (QNRecord *record in records) {
        if (record.type == kQNTypeA || record.type == kQNTypeAAAA) {
            [newRecords addObject:record];
        }
    }
    return [newRecords copy];
}
@end


//MARK: -- DNS Prefetcher
@interface QNDnsPrefetch()

// dns 预解析超时，默认3s
@property(nonatomic, assign)int dnsPrefetchTimeout;

// 最近一次预取错误信息
@property(nonatomic,  copy)NSString *lastPrefetchedErrorMessage;
/// 是否正在预取，正在预取会直接取消新的预取操作请求
@property(atomic, assign)BOOL isPrefetching;
/// 获取AutoZone时的同步锁
@property(nonatomic, strong)dispatch_semaphore_t getAutoZoneSemaphore;
/// DNS信息本地缓存key
@property(nonatomic, strong)QNDnsCacheInfo *dnsCacheInfo;
// 用户定制 dns
@property(nonatomic, strong)QNInternalDns *customDns;
// 系统 dns
@property(nonatomic, strong)QNInternalDns *systemDns;
/// prefetch hosts
@property(nonatomic, strong)NSMutableSet *prefetchHosts;
/// 缓存DNS解析结果
/// 线程安全：内部方法均是在同一线程执行，读写不必加锁，对外开放接口读操作 需要和内部写操作枷锁
@property(nonatomic, strong)NSMutableDictionary <NSString *, NSArray<QNDnsNetworkAddress *>*> *addressDictionary;
@property(nonatomic, strong)QNDnsCacheFile *diskCache;

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
        _dnsPrefetchTimeout = 3;
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
    NSArray *hosts = [self getLocalPreHost];
    @synchronized (self) {
        [self.prefetchHosts addObjectsFromArray:hosts];
    }
    [self preFetchHosts:hosts];
    [self recorderDnsCache];
    [self endPreFetch];
}
//MARK: -- 检测并预取
/// 根据token检测Dns缓存信息时效，无效则预取。 完成预取操作返回YES，反之返回NO
- (void)checkAndPrefetchDnsIfNeed:(QNZone *)currentZone token:(QNUpToken *)token{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    NSArray *hosts = [self getCurrentZoneHosts:currentZone token:token];
    if (hosts == nil) {
        return;
    }
    
    @synchronized (self) {
        [self.prefetchHosts addObjectsFromArray:hosts];
    }
    [self preFetchHosts:hosts];
    [self recorderDnsCache];
    [self endPreFetch];
}
/// 检测已预取dns是否还有效，无效则重新预取
- (void)checkWhetherCachedDnsValid{
    if ([self prepareToPreFetch] == NO) {
        return;
    }
    NSArray *hosts = nil;
    @synchronized (self) {
        hosts = [self.prefetchHosts allObjects];
    }
    [self preFetchHosts:hosts];
    [self recorderDnsCache];
    [self endPreFetch];
}

//MARK: -- 读取缓存的DNS信息
/// 根据host从缓存中读取DNS信息
- (NSArray <id <QNIDnsNetworkAddress> > *)getInetAddressByHost:(NSString *)host{

    if ([self isDnsOpen] == NO) {
        return nil;
    }
    
    [self clearDnsCacheIfNeeded];
    
    NSArray <QNDnsNetworkAddress *> *addressList = nil;
    @synchronized (self) {
        addressList = self.addressDictionary[host];
    }
    
    if (addressList && addressList.count > 0 && [addressList.firstObject isValid]) {
        return addressList;
    } else {
        return nil;
    }
}

- (void)clearDnsCache:(NSError *__autoreleasing  _Nullable *)error {
    [self clearDnsMemoryCache];
    [self clearDnsDiskCache:error];
}

//MARK: --
//MARK: -- 根据dns预取
- (NSString *)prefetchHostBySafeDns:(NSString *)host error:(NSError * __autoreleasing *)error {
    if (host == nil) {
        return nil;
    }
    NSError *err = nil;
    NSArray *nextFetchHosts = @[host];
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:self.customDns error:&err];
    if (nextFetchHosts.count == 0) {
        return [self getInetAddressByHost:host].firstObject.sourceValue;
    }
    
    if (!kQNGlobalConfiguration.dohEnable) {
        if (error != nil && err) {
            *error = err;
        }
        return nil;
    }
    
    QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kQNGlobalConfiguration.dohIpv4Servers recordType:kQNTypeA timeout:kQNGlobalConfiguration.dnsResolveTimeout];
    QNInternalDns *doh = [QNInternalDns dnsWithResolver:dohResolver];
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:&err];
    if (nextFetchHosts.count == 0) {
        return [self getInetAddressByHost:host].firstObject.sourceValue;
    }
    if (error != nil && err) {
        *error = err;
    }
    
    if ([QNIP isIpV6FullySupported]) {
        QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kQNGlobalConfiguration.dohIpv6Servers recordType:kQNTypeA timeout:kQNGlobalConfiguration.dnsResolveTimeout];
        QNInternalDns *doh = [QNInternalDns dnsWithResolver:dohResolver];
        nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:&err];
        if (error != nil && err) {
            *error = err;
        }
    }
    
    if (nextFetchHosts.count == 0) {
        return [self getInetAddressByHost:host].firstObject.sourceValue;
    } else {
        return nil;
    }
}

- (BOOL)prepareToPreFetch {
    if ([self isDnsOpen] == NO) {
        return NO;
    }
    
    self.lastPrefetchedErrorMessage = nil;
    
    if (self.isPrefetching == YES) {
        return NO;
    }
    
    [self clearDnsCacheIfNeeded];
    
    self.isPrefetching = YES;
    return YES;
}

- (void)endPreFetch{
    self.isPrefetching = NO;
}

- (void)preFetchHosts:(NSArray <NSString *> *)fetchHosts {
    NSError *err = nil;
    [self preFetchHosts:fetchHosts error:&err];
    self.lastPrefetchedErrorMessage = err.description;
}

- (void)preFetchHosts:(NSArray <NSString *> *)fetchHosts error:(NSError **)error {
    NSArray *nextFetchHosts = fetchHosts;
    
    // 定制
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:self.customDns error:error];
    if (nextFetchHosts.count == 0) {
        return;
    }
    
    // 系统
    nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:self.systemDns error:error];
    if (nextFetchHosts.count == 0) {
        return;
    }
    
    // doh
    if (kQNGlobalConfiguration.dohEnable) {
        QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kQNGlobalConfiguration.dohIpv4Servers recordType:kQNTypeA timeout:kQNGlobalConfiguration.dnsResolveTimeout];
        QNInternalDns *doh = [QNInternalDns dnsWithResolver:dohResolver];
        nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:error];
        if (nextFetchHosts.count == 0) {
            return;
        }
        
        if ([QNIP isIpV6FullySupported]) {
            QNDohResolver *dohResolver = [QNDohResolver resolverWithServers:kQNGlobalConfiguration.dohIpv6Servers recordType:kQNTypeA timeout:kQNGlobalConfiguration.dnsResolveTimeout];
            QNInternalDns *doh = [QNInternalDns dnsWithResolver:dohResolver];
            nextFetchHosts = [self preFetchHosts:nextFetchHosts dns:doh error:error];
            if (nextFetchHosts.count == 0) {
                return;
            }
        }
    }
    
    // udp
    if (kQNGlobalConfiguration.udpDnsEnable) {
        QNDnsUdpResolver *udpDnsResolver = [QNDnsUdpResolver resolverWithServerIPs:kQNGlobalConfiguration.udpDnsIpv4Servers recordType:kQNTypeA timeout:kQNGlobalConfiguration.dnsResolveTimeout];
        QNInternalDns *udpDns = [QNInternalDns dnsWithResolver:udpDnsResolver];
        [self preFetchHosts:nextFetchHosts dns:udpDns error:error];
        
        if ([QNIP isIpV6FullySupported]) {
            QNDnsUdpResolver *udpDnsResolver = [QNDnsUdpResolver resolverWithServerIPs:kQNGlobalConfiguration.udpDnsIpv6Servers recordType:kQNTypeA timeout:kQNGlobalConfiguration.dnsResolveTimeout];
            QNInternalDns *udpDns = [QNInternalDns dnsWithResolver:udpDnsResolver];
            [self preFetchHosts:nextFetchHosts dns:udpDns error:error];
        }
    }
}

- (NSArray *)preFetchHosts:(NSArray <NSString *> *)preHosts dns:(QNInternalDns *)dns error:(NSError **)error {

    if (!preHosts || preHosts.count == 0) {
        return nil;
    }
    
    if (!dns) {
        return [preHosts copy];
    }
    
    int dnsRepreHostNum = kQNGlobalConfiguration.dnsRepreHostNum;
    NSMutableArray *failHosts = [NSMutableArray array];
    for (NSString *host in preHosts) {
        int rePreNum = 0;
        BOOL isSuccess = NO;
        
        while (rePreNum < dnsRepreHostNum) {
            if ([self preFetchHost:host dns:dns error:error]) {
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

- (BOOL)preFetchHost:(NSString *)preHost dns:(QNInternalDns *)dns error:(NSError **)error {
    
    if (!preHost || preHost.length == 0) {
        return NO;
    }
    
    NSDictionary *addressDictionary = self.addressDictionary;
    NSArray<QNDnsNetworkAddress *>* preAddressList = addressDictionary[preHost];
    if (preAddressList && ![preAddressList.firstObject needRefresh]) {
        return YES;
    }
    
    NSArray <id <QNIDnsNetworkAddress> > * addressList = [dns lookup:preHost error:error];
    if (addressList && addressList.count > 0) {
        NSMutableArray *addressListP = [NSMutableArray array];
        for (id <QNIDnsNetworkAddress>inetAddress in addressList) {
            QNDnsNetworkAddress *address = [QNDnsNetworkAddress inetAddress:inetAddress];
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
        addressListP = [addressListP copy];
        @synchronized (self) {
            self.addressDictionary[preHost] = addressListP;
        }
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
    
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
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
                records[key] = [addressList copy];
            }
        }
    }
    @synchronized (self) {
        [self.addressDictionary setValuesForKeysWithDictionary:records];
    }
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
    
    NSDictionary *addressDictionary = self.addressDictionary;
    NSMutableDictionary *addressInfo = [NSMutableDictionary dictionary];
    for (NSString *key in addressDictionary.allKeys) {
       
        NSArray *addressModelList = addressDictionary[key];
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

- (void)clearDnsCacheIfNeeded{
    NSString *localIp = [QNIP local];
    if (localIp == nil || (self.dnsCacheInfo && ![localIp isEqualToString:self.dnsCacheInfo.localIp])) {
        [self clearDnsMemoryCache];
    }
}

- (void)clearDnsMemoryCache {
    @synchronized (self) {
        [self.addressDictionary removeAllObjects];
    }
}

- (void)clearDnsDiskCache:(NSError **)error {
    [self.diskCache clearCache:error];
}


//MARK: -- 获取预取hosts
- (NSArray <NSString *> *)getLocalPreHost{
    NSMutableArray *localHosts = [NSMutableArray array];
    [localHosts addObject:kQNUpLogHost];
    return [localHosts copy];
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

- (NSArray <NSString *> *)getCacheHosts{
    NSDictionary *addressDictionary = self.addressDictionary;
    return [addressDictionary copy];
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

- (QNDnsCacheFile *)diskCache {
    if (!_diskCache) {
        NSError *error;
        QNDnsCacheFile *cache = [QNDnsCacheFile dnsCacheFile:kQNGlobalConfiguration.dnsCacheDir error:&error];
        if (!error) {
            _diskCache = cache;
        }
    }
    return _diskCache;
}

- (QNInternalDns *)customDns {
    if (_systemDns == nil && kQNGlobalConfiguration.dns) {
        _systemDns = [QNInternalDns dnsWithDns:kQNGlobalConfiguration.dns];
    }
    return _systemDns;
}

- (QNInternalDns *)systemDns {
    if (_systemDns == nil) {
        _systemDns = [QNInternalDns dnsWithResolver:[[QNResolver alloc] initWithAddress:nil timeout:self.dnsPrefetchTimeout]];
    }
    return _systemDns;
}

- (NSMutableSet *)prefetchHosts {
    if (!_prefetchHosts) {
        _prefetchHosts = [NSMutableSet set];
    }
    return _prefetchHosts;
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
        [self setDnsCheckWhetherCachedValidTransactionAction];
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

BOOL kQNIsDnsSourceDoh(NSString * _Nullable source) {
    return [source containsString:kQNDnsSourceDoh];
}

BOOL kQNIsDnsSourceUdp(NSString * _Nullable source) {
    return [source containsString:kQNDnsSourceUdp];
}

BOOL kQNIsDnsSourceDnsPod(NSString * _Nullable source) {
    return [source containsString:kQNDnsSourceDnspod];
}

BOOL kQNIsDnsSourceSystem(NSString * _Nullable source) {
    return [source containsString:kQNDnsSourceSystem];
}

BOOL kQNIsDnsSourceCustom(NSString * _Nullable source) {
    return [source containsString:kQNDnsSourceCustom];
}
