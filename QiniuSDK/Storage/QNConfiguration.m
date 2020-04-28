//
//  QNConfiguration.m
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"
#import "QNHttpResponseInfo.h"
#import "QNResponseInfo.h"
#import "QNSessionManager.h"
#import "QNUpToken.h"
#import "QNUploadInfoReporter.h"
#import "QNAutoZone.h"

const UInt32 kQNBlockSize = 4 * 1024 * 1024;
const UInt32 kQNDefaultDnsCacheTime = 2 * 60;


@implementation QNConfiguration

+ (instancetype)build:(QNConfigurationBuilderBlock)block {
    QNConfigurationBuilder *builder = [[QNConfigurationBuilder alloc] init];
    block(builder);
    return [[QNConfiguration alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(QNConfigurationBuilder *)builder {
    if (self = [super init]) {

        _chunkSize = builder.chunkSize;
        _putThreshold = builder.putThreshold;
        _retryMax = builder.retryMax;
        _retryInterval = builder.retryInterval;
        _timeoutInterval = builder.timeoutInterval;

        _recorder = builder.recorder;
        _recorderKeyGen = builder.recorderKeyGen;

        _proxy = builder.proxy;

        _converter = builder.converter;
        
        _zone = builder.zone;

        _useHttps = builder.useHttps;

        _allowBackupHost = builder.allowBackupHost;
        
        _reportConfig = builder.reportConfig;

        _useConcurrentResumeUpload = builder.useConcurrentResumeUpload;
        
        _concurrentTaskCount = builder.concurrentTaskCount;
    }
    return self;
}

@end

@interface QNGloableConfiguration()
@end
@implementation QNGloableConfiguration
+ (instancetype)shared{
    static QNGloableConfiguration *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[QNGloableConfiguration alloc] init];
        [config setupData];
    });
    return config;
}
- (void)setupData{
    _isDnsOpen = YES;
    _dnscacheDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    _dnsRepreHostNum = 2;
    _dnsCacheTime = kQNDefaultDnsCacheTime;
}
@end

@implementation QNConfigurationBuilder

- (instancetype)init {
    if (self = [super init]) {
        _zone = [[QNAutoZone alloc] init];
        _chunkSize = 2 * 1024 * 1024;
        _putThreshold = 4 * 1024 * 1024;
        _retryMax = 3;
        _timeoutInterval = 60;
        _retryInterval = 0.5;
        _reportConfig = [QNReportConfig sharedInstance];

        _recorder = nil;
        _recorderKeyGen = nil;

        _proxy = nil;
        _converter = nil;

        _useHttps = YES;
        _allowBackupHost = YES;
        _useConcurrentResumeUpload = NO;
        _concurrentTaskCount = 3;
    }
    return self;
}

@end
//@implementation QNZonesInfo
//
//- (instancetype)initWithZonesInfo:(NSArray<QNBaseZoneInfo *> *)zonesInfo
//{
//    self = [super init];
//    if (self) {
//        _zonesInfo = zonesInfo;
//    }
//    return self;
//}
//
//+ (instancetype)buildZonesInfoWithResp:(NSDictionary *)resp {
//
//    NSMutableArray *zonesInfo = [NSMutableArray array];
//    NSArray *hosts = resp[@"hosts"];
//    for (NSInteger i = 0; i < hosts.count; i++) {
//        QNBaseZoneInfo *zoneInfo = [[[QNBaseZoneInfo alloc] init] buildInfoFromJson:hosts[i]];
//        zoneInfo.type = i == 0 ? QNZoneInfoTypeMain : QNZoneInfoTypeBackup;
//        [zonesInfo addObject:zoneInfo];
//    }
//    return [[[self class] alloc] initWithZonesInfo:zonesInfo];
//}
//
//- (QNBaseZoneInfo *)getZoneInfoWithType:(QNZoneInfoType)type {
//
//    QNBaseZoneInfo *zoneInfo = nil;
//    for (QNBaseZoneInfo *info in _zonesInfo) {
//        if (info.type == type) {
//            zoneInfo = info;
//            break;
//        }
//    }
//    return zoneInfo;
//}
//
//- (NSString *)getZoneInfoRegionNameWithType:(QNZoneInfoType)type {
//
//    QNBaseZoneInfo *zoneInfo = [self getZoneInfoWithType:type];
//    return zoneNames[zoneInfo.zoneRegion];
//}
//
//- (BOOL)hasBackupZone {
//    return _zonesInfo.count > 1;
//}
//
//@end
//
//@implementation QNZone
//
//- (NSString *)upHost:(QNBaseZoneInfo *)zoneInfo
//             isHttps:(BOOL)isHttps
//          lastUpHost:(NSString *)lastUpHost {
//    NSString *upHost = nil;
//    NSString *upDomain = nil;
//
//    // frozen domain
//    if (lastUpHost) {
//        NSString *upLastDomain = nil;
//        if (isHttps) {
//            upLastDomain = [lastUpHost substringFromIndex:8];
//        } else {
//            upLastDomain = [lastUpHost substringFromIndex:7];
//        }
//        [zoneInfo frozenDomain:upLastDomain];
//    }
//
//    //get backup domain
//    for (NSString *backupDomain in zoneInfo.upDomainsList) {
//        NSDate *frozenTill = zoneInfo.upDomainsDic[backupDomain];
//        NSDate *now = [NSDate date];
//        if ([frozenTill compare:now] == NSOrderedAscending) {
//            upDomain = backupDomain;
//            break;
//        }
//    }
//    if (upDomain) {
//        [zoneInfo.upDomainsDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:upDomain];
//    } else {
//
//        //reset all the up host frozen time
//        if (!lastUpHost) {
//            for (NSString *domain in zoneInfo.upDomainsList) {
//                [zoneInfo.upDomainsDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:domain];
//            }
//            if (zoneInfo.upDomainsList.count > 0) {
//                upDomain = zoneInfo.upDomainsList[0];
//            }
//        }
//    }
//
//    if (upDomain) {
//        if (isHttps) {
//            upHost = [NSString stringWithFormat:@"https://%@", upDomain];
//        } else {
//            upHost = [NSString stringWithFormat:@"http://%@", upDomain];
//        }
//    }
//    return upHost;
//}
//
//- (NSString *)up:(QNUpToken *)token
//zoneInfoType:(QNZoneInfoType)zoneInfoType
//         isHttps:(BOOL)isHttps
//    frozenDomain:(NSString *)frozenDomain {
//    return nil;
//}
//
//- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
//    return nil;
//}
//
//- (void)preQueryWithToken:(QNUpToken *)token
//              on:(QNPrequeryReturn)ret {
//    ret(0, nil);
//}
//
//@end
//
//@interface QNFixedZone ()
//
//@property (nonatomic, strong) QNZonesInfo *zonesInfo;
//
//@end
//
//@implementation QNFixedZone
//
//- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList {
//    return [[QNFixedZone alloc] initWithupDomainList:upList zoneRegion:QNZoneRegion_unknown];
//}
//
//- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList zoneRegion:(QNZoneRegion)zoneRegion {
//    if (self = [super init]) {
//        self.zonesInfo = [self createZonesInfo:upList zoneRegion:zoneRegion];
//    }
//    return self;
//}
//
//+ (instancetype)zone0 {
//    static QNFixedZone *z0 = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        static const NSArray<NSString *> *uplist = nil;
//        if (!uplist) {
//            uplist = [[NSArray alloc] initWithObjects:@"upload.qiniup.com", @"upload-nb.qiniup.com",
//                                                      @"upload-xs.qiniup.com", @"up.qiniup.com",
//                                                      @"up-nb.qiniup.com", @"up-xs.qiniup.com",
//                                                      @"upload.qbox.me", @"up.qbox.me", nil];
//            z0 = [[QNFixedZone alloc] initWithupDomainList:(NSArray<NSString *> *)uplist zoneRegion:QNZoneRegion_z0];
//        }
//    });
//    return z0;
//}
//
//+ (instancetype)zone1 {
//    static QNFixedZone *z1 = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        static const NSArray<NSString *> *uplist = nil;
//        if (!uplist) {
//            uplist = [[NSArray alloc] initWithObjects:@"upload-z1.qiniup.com", @"up-z1.qiniup.com",
//                                                      @"upload-z1.qbox.me", @"up-z1.qbox.me", nil];
//            z1 = [[QNFixedZone alloc] initWithupDomainList:(NSArray<NSString *> *)uplist zoneRegion:QNZoneRegion_z1];
//        }
//    });
//    return z1;
//}
//
//+ (instancetype)zone2 {
//    static QNFixedZone *z2 = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        static const NSArray<NSString *> *uplist = nil;
//        if (!uplist) {
//            uplist = [[NSArray alloc] initWithObjects:@"upload-z2.qiniup.com", @"upload-gz.qiniup.com",
//                                                      @"upload-fs.qiniup.com", @"up-z2.qiniup.com",
//                                                      @"up-gz.qiniup.com", @"up-fs.qiniup.com",
//                                                      @"upload-z2.qbox.me", @"up-z2.qbox.me", nil];
//            z2 = [[QNFixedZone alloc] initWithupDomainList:(NSArray<NSString *> *)uplist zoneRegion:QNZoneRegion_z2];
//        }
//    });
//    return z2;
//}
//
//+ (instancetype)zoneNa0 {
//    static QNFixedZone *zNa0 = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        static const NSArray<NSString *> *uplist = nil;
//        if (!uplist) {
//            uplist = [[NSArray alloc] initWithObjects:@"upload-na0.qiniup.com", @"up-na0.qiniup.com",
//                                                      @"upload-na0.qbox.me", @"up-na0.qbox.me", nil];
//            zNa0 = [[QNFixedZone alloc] initWithupDomainList:(NSArray<NSString *> *)uplist zoneRegion:QNZoneRegion_na0];
//        }
//    });
//    return zNa0;
//}
//
//+ (instancetype)zoneAs0 {
//    static QNFixedZone *zAs0 = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        static const NSArray<NSString *> *uplist = nil;
//        if (!uplist) {
//            uplist = [[NSArray alloc] initWithObjects:@"upload-as0.qiniup.com", @"up-as0.qiniup.com",
//                                                      @"upload-as0.qbox.me", @"up-as0.qbox.me", nil];
//            zAs0 = [[QNFixedZone alloc] initWithupDomainList:(NSArray<NSString *> *)uplist zoneRegion:QNZoneRegion_as0];
//        }
//    });
//    return zAs0;
//}
//
//- (QNZonesInfo *)createZonesInfo:(NSArray<NSString *> *)upDomainList zoneRegion:(QNZoneRegion)zoneRegion {
//    NSMutableDictionary *upDomainDic = [[NSMutableDictionary alloc] init];
//    for (NSString *upDomain in upDomainList) {
//        [upDomainDic setValue:[NSDate dateWithTimeIntervalSince1970:0] forKey:upDomain];
//    }
//    QNBaseZoneInfo *zoneInfo = [[QNBaseZoneInfo alloc] init:86400 upDomainsList:(NSMutableArray<NSString *> *)upDomainList upDomainsDic:upDomainDic zoneRegion:zoneRegion];
//    QNZonesInfo *zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:@[zoneInfo]];
//    return zonesInfo;
//}
//
//- (void)preQueryWithToken:(QNUpToken *)token
//                       on:(QNPrequeryReturn)ret {
//    ret(0, nil);
//}
//
//- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
//    return self.zonesInfo;
//}
//
//- (NSString *)up:(QNUpToken *)token
//zoneInfoType:(QNZoneInfoType)zoneInfoType
//         isHttps:(BOOL)isHttps
//    frozenDomain:(NSString *)frozenDomain {
//
//    if (self.zonesInfo == nil) {
//        return nil;
//    }
//    return [super upHost:[self.zonesInfo getZoneInfoWithType:QNZoneInfoTypeMain] isHttps:isHttps lastUpHost:frozenDomain];
//}
//
//@end
//
//@implementation QNAutoZone {
//    NSString *server;
//    NSMutableDictionary *cache;
//    NSLock *lock;
//    QNSessionManager *sesionManager;
//}
//
//- (instancetype)init{
//    if (self = [super init]) {
//        server = @"https://uc.qbox.me";
//        cache = [NSMutableDictionary new];
//        lock = [NSLock new];
//        sesionManager = [[QNSessionManager alloc] initWithProxy:nil timeout:10 urlConverter:nil];
//    }
//    return self;
//}
//
//- (NSString *)up:(QNUpToken *)token
//    zoneInfoType:(QNZoneInfoType)zoneInfoType
//         isHttps:(BOOL)isHttps
//    frozenDomain:(NSString *)frozenDomain {
//    NSString *index = [token index];
//    [lock lock];
//    QNZonesInfo *zonesInfo = [cache objectForKey:index];
//    [lock unlock];
//    if (zonesInfo == nil) {
//        return nil;
//    }
//    return  [self upHost:[zonesInfo getZoneInfoWithType:zoneInfoType] isHttps:isHttps lastUpHost:frozenDomain];
//}
//
//- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
//    if (token == nil) return nil;
//    [lock lock];
//    QNZonesInfo *zonesInfo = [cache objectForKey:[token index]];
//    [lock unlock];
//    return zonesInfo;
//}
//
//- (void)preQueryWithToken:(QNUpToken *)token
//                       on:(QNPrequeryReturn)ret {
//    if (token == nil) {
//        ret(-1, nil);
//    }
//    [lock lock];
//    QNZonesInfo *zonesInfo = [cache objectForKey:[token index]];
//    [lock unlock];
//    if (zonesInfo != nil) {
//        ret(0, nil);
//        return;
//    }
//
//    //https://uc.qbox.me/v3/query?ak=T3sAzrwItclPGkbuV4pwmszxK7Ki46qRXXGBBQz3&bucket=if-pbl
//    NSString *url = [NSString stringWithFormat:@"%@/v3/query?ak=%@&bucket=%@", server, token.access, token.bucket];
//    [sesionManager get:url withHeaders:nil withCompleteBlock:^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
//        if (!httpResponseInfo.error) {
//
//            QNZonesInfo *zonesInfo = [QNZonesInfo buildZonesInfoWithResp:respBody];
//            if (httpResponseInfo == nil) {
//                ret(kQNInvalidToken, httpResponseInfo);
//            } else {
//                [self->lock lock];
//                [self->cache setValue:zonesInfo forKey:[token index]];
//                [self->lock unlock];
//                ret(0, httpResponseInfo);
//            }
//        } else {
//            ret(kQNNetworkError, httpResponseInfo);
//        }
//    }];
//}

//@end

