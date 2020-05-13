//
//  QNZoneInfo.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"

@interface QNUploadServerGroup()

@property(nonatomic,   copy)NSString *info;
@property(nonatomic, strong)NSArray <NSString *> *main;
@property(nonatomic, strong)NSArray <NSString *> *backup;
@property(nonatomic, strong)NSArray <NSString *> *allHosts;

@end
@implementation QNUploadServerGroup
+ (QNUploadServerGroup *)buildInfoFromDictionary:(NSDictionary *)dictionary{
    
    NSMutableArray *allHosts = [NSMutableArray array];
    QNUploadServerGroup *group = [[QNUploadServerGroup alloc] init];
    group.info = dictionary[@"info"];
    if ([dictionary[@"main"] isKindOfClass:[NSArray class]]) {
        group.main = dictionary[@"main"];
        [allHosts addObjectsFromArray:group.main];
    }
    if ([dictionary[@"backup"] isKindOfClass:[NSArray class]]) {
        group.backup = dictionary[@"backup"];
        [allHosts addObjectsFromArray:group.backup];
    }
    group.allHosts = [allHosts copy];
    return group;
}
@end


@interface QNZoneInfo()

@property(nonatomic, assign) QNZoneRegion zoneRegion;
@property(nonatomic, assign) long ttl;
@property(nonatomic, strong) NSDate *buildDate;

@property(nonatomic, strong)NSArray <NSString *> *allHosts;
@property(nonatomic, strong) NSDictionary *detailInfo;

@end
@implementation QNZoneInfo

+ (QNZoneInfo *)zoneInfoWithMainHosts:(NSArray *)mainHosts
                              ioHosts:(NSArray *)ioHosts{
    
    if (!mainHosts || mainHosts.count == 0) {
        return nil;
    }
    
    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:@{@"ttl" : @(86400*1000),
                                                                @"up" : @{@"acc" : @{@"main" : mainHosts}},
                                                                @"io" : @{@"src" : @{@"main" : ioHosts ?: @[]}}}];
    return zoneInfo;
}

+ (QNZoneInfo *)zoneInfoFromDictionary:(NSDictionary *)detailInfo {
    if (![detailInfo isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    long ttl = [[detailInfo objectForKey:@"ttl"] longValue];
    NSDictionary *up = [detailInfo objectForKey:@"up"];
    NSDictionary *acc = [up objectForKey:@"acc"];
    NSDictionary *src = [up objectForKey:@"src"];
    NSDictionary *old_acc = [up objectForKey:@"old_acc"];
    NSDictionary *old_src = [up objectForKey:@"old_src"];
    
    // judge zone region via io
    NSDictionary *io = [detailInfo objectForKey:@"io"];
    NSDictionary *io_src = [io objectForKey:@"src"];
    NSArray *io_main = [io_src objectForKey:@"main"];
    NSString *io_host = io_main.count > 0 ? io_main[0] : nil;
    
    QNZoneRegion zoneRegion = QNZoneRegion_unknown;
    if ([io_host isEqualToString:@"iovip.qbox.me"]) {
        zoneRegion = QNZoneRegion_z0;
    } else if ([io_host isEqualToString:@"iovip-z1.qbox.me"]) {
        zoneRegion = QNZoneRegion_z1;
    } else if ([io_host isEqualToString:@"iovip-z2.qbox.me"]) {
        zoneRegion = QNZoneRegion_z2;
    } else if ([io_host isEqualToString:@"iovip-na0.qbox.me"]) {
        zoneRegion = QNZoneRegion_na0;
    } else if ([io_host isEqualToString:@"iovip-as0.qbox.me"]) {
        zoneRegion = QNZoneRegion_as0;
    } else {
        zoneRegion = QNZoneRegion_unknown;
    }
    
    QNZoneInfo *zoneInfo = [[QNZoneInfo alloc] init:ttl zoneRegion:zoneRegion];
    zoneInfo.acc = [QNUploadServerGroup buildInfoFromDictionary:acc];
    zoneInfo.src = [QNUploadServerGroup buildInfoFromDictionary:src];
    zoneInfo.old_acc = [QNUploadServerGroup buildInfoFromDictionary:old_acc];
    zoneInfo.old_src = [QNUploadServerGroup buildInfoFromDictionary:old_src];
    
    NSMutableArray *allHosts = [NSMutableArray array];
    [allHosts addObjectsFromArray:zoneInfo.acc.allHosts];
    [allHosts addObjectsFromArray:zoneInfo.src.allHosts];
    [allHosts addObjectsFromArray:zoneInfo.old_acc.allHosts];
    [allHosts addObjectsFromArray:zoneInfo.old_src.allHosts];
    zoneInfo.allHosts = [allHosts copy];
    
    zoneInfo.detailInfo = detailInfo;
    
    return zoneInfo;
}

- (instancetype)init:(long)ttl
        zoneRegion:(QNZoneRegion)zoneRegion {
    if (self = [super init]) {
        _ttl = ttl;
        _buildDate = [NSDate date];
        _zoneRegion = zoneRegion;
        
        NSArray *zoneRegionIds = @[@"z0", @"z1", @"z2", @"as0", @"na0", @"unknown"];
        if (zoneRegion < zoneRegionIds.count) {
            _zoneRegionId = zoneRegionIds[zoneRegion];
        } else {
            _zoneRegionId = @"unknown";
        }
    }
    return self;
}

- (BOOL)isValid{
    NSDate *currentDate = [NSDate date];
    if (self.ttl > [currentDate timeIntervalSinceDate:self.buildDate]) {
        return YES;
    } else {
        return NO;
    }
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
    
    NSMutableArray *zonesInfo = [NSMutableArray array];
    NSArray *hosts = dictionary[@"hosts"];
    for (NSInteger i = 0; i < hosts.count; i++) {
        QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:hosts[i]];
        if (zoneInfo) {
            [zonesInfo addObject:zoneInfo];
        }
    }
    return [[[self class] alloc] initWithZonesInfo:zonesInfo];
}


@end
