//
//  QNFixZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNFixedZone.h"
#import "QNZoneInfo.h"

@interface QNFixedZone ()

@property (nonatomic, strong) QNZonesInfo *zonesInfo;

@end

@implementation QNFixedZone

- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList ioHost:nil];
    }
    return self;
}
- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList
                              ioHost:(NSArray<NSString *> *)ioHost {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList ioHost:ioHost];
    }
    return self;
}

+ (instancetype)createWithHost:(NSArray<NSString *> *)upList {
    return [[QNFixedZone alloc] initWithupDomainList:upList ioHost:nil];
}

+ (instancetype)zone0 {
    static QNFixedZone *z0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const NSArray<NSString *> *uplist = nil;
        if (!uplist) {
            uplist = [[NSArray alloc] initWithObjects:@"upload.qiniup.com", @"upload-nb.qiniup.com",
                                                      @"upload-xs.qiniup.com", @"up.qiniup.com",
                                                      @"up-nb.qiniup.com", @"up-xs.qiniup.com",
                                                      @"upload.qbox.me", @"up.qbox.me", nil];
            z0 = [[QNFixedZone alloc] initWithupDomainList:(NSArray <NSString *> *)uplist ioHost:@[@"iovip.qbox.me"]];
        }
    });
    return z0;
}

+ (instancetype)zone1 {
    static QNFixedZone *z1 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const NSArray<NSString *> *uplist = nil;
        if (!uplist) {
            uplist = [[NSArray alloc] initWithObjects:@"upload-z1.qiniup.com", @"up-z1.qiniup.com",
                                                      @"upload-z1.qbox.me", @"up-z1.qbox.me", nil];
            z1 = [[QNFixedZone alloc] initWithupDomainList:(NSArray <NSString *> *)uplist ioHost:@[@"iovip-z1.qbox.mee"]];
        }
    });
    return z1;
}

+ (instancetype)zone2 {
    static QNFixedZone *z2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const NSArray<NSString *> *uplist = nil;
        if (!uplist) {
            uplist = [[NSArray alloc] initWithObjects:@"upload-z2.qiniup.com", @"upload-gz.qiniup.com",
                                                      @"upload-fs.qiniup.com", @"up-z2.qiniup.com",
                                                      @"up-gz.qiniup.com", @"up-fs.qiniup.com",
                                                      @"upload-z2.qbox.me", @"up-z2.qbox.me", nil];
            z2 = [[QNFixedZone alloc] initWithupDomainList:(NSArray <NSString *> *)uplist ioHost:@[@"iovip-z2.qbox.mee"]];
        }
    });
    return z2;
}

+ (instancetype)zoneNa0 {
    static QNFixedZone *zNa0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const NSArray<NSString *> *uplist = nil;
        if (!uplist) {
            uplist = [[NSArray alloc] initWithObjects:@"upload-na0.qiniup.com", @"up-na0.qiniup.com",
                                                      @"upload-na0.qbox.me", @"up-na0.qbox.me", nil];
            zNa0 = [[QNFixedZone alloc] initWithupDomainList:(NSArray <NSString *> *)uplist ioHost:@[@"iovip-na0.qbox.me"]];
        }
    });
    return zNa0;
}

+ (instancetype)zoneAs0 {
    static QNFixedZone *zAs0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const NSArray<NSString *> *uplist = nil;
        if (!uplist) {
            uplist = [[NSArray alloc] initWithObjects:@"upload-as0.qiniup.com", @"up-as0.qiniup.com",
                                                      @"upload-as0.qbox.me", @"up-as0.qbox.me", nil];
            zAs0 = [[QNFixedZone alloc] initWithupDomainList:(NSArray <NSString *> *)uplist ioHost:@[@"iovip-as0.qbox.me"]];
        }
    });
    return zAs0;
}

+ (NSArray <QNFixedZone *> *)localsZoneInfo{

    NSArray *zonesInfo = @[[QNFixedZone zone0],
                           [QNFixedZone zone1],
                           [QNFixedZone zone2],
                           [QNFixedZone zoneNa0],
                           [QNFixedZone zoneAs0]];
    return zonesInfo;
}

- (QNZonesInfo *)createZonesInfo:(NSArray <NSString *> *)upDomainList
                          ioHost:(NSArray <NSString *> *)ioHost {
    if (!upDomainList && upDomainList.count == 0) {
        return nil;
    }
//    NSMutableDictionary *upDomainDic = [[NSMutableDictionary alloc] init];
//    for (NSString *upDomain in upDomainList) {
//        [upDomainDic setValue:[NSDate dateWithTimeIntervalSince1970:0] forKey:upDomain];
//    }
//    QNZoneInfo *zoneInfo = [[QNZoneInfo alloc] init:86400 upDomainsList:(NSMutableArray<NSString *> *)upDomainList upDomainsDic:upDomainDic zoneRegion:zoneRegion];
    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:@{@"ttl" : @(86400),
                                                                @"up" : @{@"acc" : @{@"main" : upDomainList}},
                                                                @"io" : @{@"src" : @{@"main" : ioHost ?: @[]}}}];
    QNZonesInfo *zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:@[zoneInfo]];
    return zonesInfo;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    ret(0, nil);
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    return self.zonesInfo;
}

- (NSString *)up:(QNUpToken *)token
    zoneInfoType:(QNZoneInfoType)zoneInfoType
         isHttps:(BOOL)isHttps
    frozenDomain:(NSString *)frozenDomain {

    if (self.zonesInfo == nil) {
        return nil;
    }
    return [super upHost:[self.zonesInfo getZoneInfoWithType:QNZoneInfoTypeMain] isHttps:isHttps lastUpHost:frozenDomain];
}

@end
