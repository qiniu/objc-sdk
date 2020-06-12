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
        self.zonesInfo = [self createZonesInfo:upList ioHosts:nil];
    }
    return self;
}
- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList
                              ioHost:(NSArray<NSString *> *)ioHost {
    if (self = [super init]) {
        self.zonesInfo = [self createZonesInfo:upList ioHosts:ioHost];
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
        NSArray<NSString *> *uplist = @[@"upload.qiniup.com", @"up.qiniup.com",
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
        NSArray<NSString *> *uplist = @[@"upload-z2.qiniup.com", @"up-z2.qiniup.com",
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

+ (QNFixedZone *)localsZoneInfo{

    NSArray *zones = @[[QNFixedZone zone0],
                       [QNFixedZone zone1],
                       [QNFixedZone zone2],
                       [QNFixedZone zoneNa0],
                       [QNFixedZone zoneAs0]];
    
    NSMutableArray <QNZoneInfo *> *zoneInfoArray = [NSMutableArray array];
    for (QNFixedZone *zone in zones) {
        if (zone.zonesInfo.zonesInfo) {
            [zoneInfoArray addObjectsFromArray:zone.zonesInfo.zonesInfo];
        }
    }
    
    QNFixedZone *fixedZone = [[QNFixedZone alloc] init];
    fixedZone.zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:[zoneInfoArray copy]];
    return fixedZone;
}

- (QNZonesInfo *)createZonesInfo:(NSArray <NSString *> *)upDomains
                         ioHosts:(NSArray <NSString *> *)ioHosts {
    if (!upDomains && upDomains.count == 0) {
        return nil;
    }

    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoWithMainHosts:upDomains ioHosts:ioHosts];
    QNZonesInfo *zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:@[zoneInfo]];
    return zonesInfo;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    ret(0, nil, nil);
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    return self.zonesInfo;
}


@end
