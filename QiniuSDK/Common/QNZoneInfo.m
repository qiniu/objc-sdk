//
//  QNZoneInfo.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"

static NSString *const zoneNames[] = {@"z0", @"z1", @"z2", @"as0", @"na0", @"unknown"};

@interface QNZoneInfo()

@property (nonatomic, assign) QNZoneInfoType type;
@property (nonatomic, assign) QNZoneRegion zoneRegion;
@property (nonatomic, assign) long ttl;
@property (nonatomic, strong) NSDate *buildDate;
@property (nonatomic, strong) NSMutableArray<NSString *> *upDomainsList;
@property (nonatomic, strong) NSMutableDictionary *upDomainsDic;

@end
@implementation QNZoneInfo

- (instancetype)init:(long)ttl
       upDomainsList:(NSMutableArray<NSString *> *)upDomainsList
        upDomainsDic:(NSMutableDictionary *)upDomainsDic
        zoneRegion:(QNZoneRegion)zoneRegion {
    if (self = [super init]) {
        _ttl = ttl;
        _buildDate = [NSDate date];
        _upDomainsList = upDomainsList;
        _upDomainsDic = upDomainsDic;
        _zoneRegion = zoneRegion;
        _type = QNZoneInfoTypeMain;
    }
    return self;
}

- (QNZoneInfo *)buildInfoFromJson:(NSDictionary *)resp {
    long ttl = [[resp objectForKey:@"ttl"] longValue];
    NSDictionary *up = [resp objectForKey:@"up"];
    NSArray *domains = [up objectForKey:@"domains"];
    NSArray *oldDomains = [up objectForKey:@"old"];
    
    NSMutableArray *domainList = [[NSMutableArray alloc] init];
    NSMutableDictionary *domainDic = [[NSMutableDictionary alloc] init];
    for (int i = 0; i < domains.count; i++) {
        [domainList addObject:domains[i]];
        [domainDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:domains[i]];
    }
    for (int i = 0; i < oldDomains.count; i++) {
        [domainList addObject:oldDomains[i]];
        [domainDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:oldDomains[i]];
    }
    
    // judge zone region via io
    NSString *regionId = [resp objectForKey:@"regionId"];
    
    QNZoneRegion zoneRegion = QNZoneRegion_unknown;
    if ([regionId isKindOfClass:[NSString class]]) {
        if ([regionId isEqualToString:@"z0"]) {
            zoneRegion = QNZoneRegion_z0;
        } else if ([regionId isEqualToString:@"z1"]) {
            zoneRegion = QNZoneRegion_z1;
        } else if ([regionId isEqualToString:@"z2"]) {
            zoneRegion = QNZoneRegion_z2;
        } else if ([regionId isEqualToString:@"as0"]) {
            zoneRegion = QNZoneRegion_na0;
        } else if ([regionId isEqualToString:@"na0"]) {
            zoneRegion = QNZoneRegion_as0;
        } else {
            zoneRegion = QNZoneRegion_unknown;
        }
    }
    
    return [[QNZoneInfo alloc] init:ttl upDomainsList:domainList upDomainsDic:domainDic zoneRegion:zoneRegion];
}

- (void)frozenDomain:(NSString *)domain {
    NSTimeInterval secondsFor10min = 10 * 60;
    NSDate *tomorrow = [NSDate dateWithTimeIntervalSinceNow:secondsFor10min];
    [self.upDomainsDic setObject:tomorrow forKey:domain];
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

+ (instancetype)buildZonesInfoWithResp:(NSDictionary *)resp {
    
    NSMutableArray *zonesInfo = [NSMutableArray array];
    NSArray *hosts = resp[@"hosts"];
    for (NSInteger i = 0; i < hosts.count; i++) {
        QNZoneInfo *zoneInfo = [[[QNZoneInfo alloc] init] buildInfoFromJson:hosts[i]];
        zoneInfo.type = i == 0 ? QNZoneInfoTypeMain : QNZoneInfoTypeBackup;
        [zonesInfo addObject:zoneInfo];
    }
    return [[[self class] alloc] initWithZonesInfo:zonesInfo];
}

- (QNZoneInfo *)getZoneInfoWithType:(QNZoneInfoType)type {
    
    QNZoneInfo *zoneInfo = nil;
    for (QNZoneInfo *info in _zonesInfo) {
        if (info.type == type) {
            zoneInfo = info;
            break;
        }
    }
    return zoneInfo;
}

- (NSString *)getZoneInfoRegionNameWithType:(QNZoneInfoType)type {
    
    QNZoneInfo *zoneInfo = [self getZoneInfoWithType:type];
    return zoneNames[zoneInfo.zoneRegion];
}

- (BOOL)hasBackupZone {
    return _zonesInfo.count > 1;
}

@end
