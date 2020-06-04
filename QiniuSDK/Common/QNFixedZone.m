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
        self.zonesInfo = [self createZonesInfo:upList zoneRegion:QNZoneRegion_unknown];
    }
    return self;
}
- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList
                          zoneRegion:(QNZoneRegion)zoneRegion {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList zoneRegion:zoneRegion];
    }
    return self;
}

+ (instancetype)createWithHost:(NSArray<NSString *> *)upList {
    return [[QNFixedZone alloc] initWithupDomainList:upList zoneRegion:QNZoneRegion_unknown];
}

+ (instancetype)zone0 {
    static QNFixedZone *z0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *uplist = @[@"upload.qiniup.com", @"upload-nb.qiniup.com",
                                        @"upload-xs.qiniup.com", @"up.qiniup.com",
                                        @"up-nb.qiniup.com", @"up-xs.qiniup.com",
                                        @"upload.qbox.me", @"up.qbox.me"];
        z0 = [QNFixedZone createWithHost:(NSArray<NSString *> *)uplist];
    });
    return z0;
}

+ (instancetype)zone1 {
    static QNFixedZone *z1 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *uplist = @[@"upload-z1.qiniup.com", @"up-z1.qiniup.com",
                                        @"upload-z1.qbox.me", @"up-z1.qbox.me"];
        z1 = [QNFixedZone createWithHost:(NSArray<NSString *> *)uplist];
    });
    return z1;
}

+ (instancetype)zone2 {
    static QNFixedZone *z2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *uplist = @[@"upload-z2.qiniup.com", @"upload-gz.qiniup.com",
                                        @"upload-fs.qiniup.com", @"up-z2.qiniup.com",
                                        @"up-gz.qiniup.com", @"up-fs.qiniup.com",
                                        @"upload-z2.qbox.me", @"up-z2.qbox.me"];
        z2 = [QNFixedZone createWithHost:(NSArray<NSString *> *)uplist];
    });
    return z2;
}

+ (instancetype)zoneNa0 {
    static QNFixedZone *zNa0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *uplist = @[@"upload-na0.qiniup.com", @"up-na0.qiniup.com",
                                        @"upload-na0.qbox.me", @"up-na0.qbox.me"];
        zNa0 = [QNFixedZone createWithHost:(NSArray<NSString *> *)uplist];
    });
    return zNa0;
}

+ (instancetype)zoneAs0 {
    static QNFixedZone *zAs0 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *uplist = @[@"upload-as0.qiniup.com", @"up-as0.qiniup.com",
                                        @"upload-as0.qbox.me", @"up-as0.qbox.me"];
        zAs0 = [QNFixedZone createWithHost:(NSArray<NSString *> *)uplist];
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

- (QNZonesInfo *)createZonesInfo:(NSArray<NSString *> *)upDomainList
                      zoneRegion:(QNZoneRegion)zoneRegion {
    NSMutableDictionary *upDomainDic = [[NSMutableDictionary alloc] init];
    for (NSString *upDomain in upDomainList) {
        [upDomainDic setValue:[NSDate dateWithTimeIntervalSince1970:0] forKey:upDomain];
    }
    QNZoneInfo *zoneInfo = [[QNZoneInfo alloc] init:86400 upDomainsList:(NSMutableArray<NSString *> *)upDomainList upDomainsDic:upDomainDic zoneRegion:zoneRegion];
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
