//
//  QNZoneInfo.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"

NSString * const QNZoneInfoSDKDefaultIOHost = @"sdkDefaultIOHost";
NSString * const QNZoneInfoEmptyRegionId = @"sdkEmptyRegionId";

@interface QNZoneInfo()

@property(nonatomic, strong) NSDate *buildDate;

@property(nonatomic, assign) long ttl;
@property(nonatomic, strong)NSArray<NSString *> *domains;
@property(nonatomic, strong)NSArray<NSString *> *old_domains;

@property(nonatomic, strong)NSArray <NSString *> *allHosts;
@property(nonatomic, strong) NSDictionary *detailInfo;

@end
@implementation QNZoneInfo

+ (QNZoneInfo *)zoneInfoWithMainHosts:(NSArray <NSString *> *)mainHosts
                             regionId:(NSString * _Nullable)regionId{
    return [self zoneInfoWithMainHosts:mainHosts oldHosts:nil regionId:regionId];
}

+ (QNZoneInfo *)zoneInfoWithMainHosts:(NSArray <NSString *> *)mainHosts
                             oldHosts:(NSArray <NSString *> * _Nullable)oldHosts
                             regionId:(NSString * _Nullable)regionId{
    
    if (!mainHosts || ![mainHosts isKindOfClass:[NSArray class]] || mainHosts.count == 0) {
        return nil;
    }
    
    if (mainHosts && ![mainHosts isKindOfClass:[NSArray class]]) {
        mainHosts = nil;
    }
    
    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:@{@"ttl" : @(86400*1000),
                                                                @"region" : regionId ?: QNZoneInfoEmptyRegionId,
                                                                @"up" : @{@"domains" : mainHosts ?: @[],
                                                                          @"old" : oldHosts ?: @[]},
                                                                }];
    return zoneInfo;
}

+ (QNZoneInfo *)zoneInfoFromDictionary:(NSDictionary *)detailInfo {
    if (![detailInfo isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSString *regionId = [detailInfo objectForKey:@"region"];
    if (regionId == nil) {
        regionId = QNZoneInfoEmptyRegionId;
    }
    long ttl = [[detailInfo objectForKey:@"ttl"] longValue];
    NSDictionary *up = [detailInfo objectForKey:@"up"];
    NSArray *domains = [up objectForKey:@"domains"];
    NSArray *old_domains = [up objectForKey:@"old"];
    
    NSMutableArray *allHosts = [NSMutableArray array];
    QNZoneInfo *zoneInfo = [[QNZoneInfo alloc] init:ttl regionId:regionId];
    if ([domains isKindOfClass:[NSArray class]]) {
        zoneInfo.domains = domains;
        [allHosts addObjectsFromArray:domains];
    }
    if ([old_domains isKindOfClass:[NSArray class]]) {
        zoneInfo.old_domains = old_domains;
        [allHosts addObjectsFromArray:old_domains];
    }
    zoneInfo.allHosts = [allHosts copy];
    
    zoneInfo.detailInfo = detailInfo;
    
    return zoneInfo;
}

- (instancetype)init:(long)ttl
            regionId:(NSString *)regionId {
    if (self = [super init]) {
        _ttl = ttl;
        _buildDate = [NSDate date];
        _regionId = regionId;
    }
    return self;
}

- (BOOL)isValid{
    NSDate *currentDate = [NSDate date];
    return self.ttl > [currentDate timeIntervalSinceDate:self.buildDate];
}

@end

@interface QNZonesInfo()
@end
@implementation QNZonesInfo

- (instancetype)initWithZonesInfo:(NSArray<QNZoneInfo *> *)zonesInfo{
    self = [super init];
    if (self) {
        _zonesInfo = zonesInfo;
    }
    return self;
}

+ (instancetype)infoWithDictionary:(NSDictionary *)dictionary {
    
    NSArray *hosts = dictionary[@"hosts"];
    NSMutableArray *zonesInfo = [NSMutableArray array];
    if ([hosts isKindOfClass:[NSArray class]]) {
        for (NSInteger i = 0; i < hosts.count; i++) {
            QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:hosts[i]];
            if (zoneInfo) {
                [zonesInfo addObject:zoneInfo];
            }
        }
    }
    return [[[self class] alloc] initWithZonesInfo:zonesInfo];
}


@end
