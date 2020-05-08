//
//  QNZoneInfo.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"

static NSString *const zoneNames[] = {@"z0", @"z1", @"z2", @"as0", @"na0", @"unknown"};

@interface QNUploadServerGroup()
@end
@implementation QNUploadServerGroup
+ (QNUploadServerGroup *)buildInfoFromDictionary:(NSDictionary *)dictionary{
    QNUploadServerGroup *group = [[QNUploadServerGroup alloc] init];
    group.info = dictionary[@"info"];
    if ([dictionary[@"main"] isKindOfClass:[NSArray class]]) {
        group.main = dictionary[@"main"];
    }
    if ([dictionary[@"backup"] isKindOfClass:[NSArray class]]) {
        group.backup = dictionary[@"backup"];
    }
    return group;
}
@end


@interface QNZoneInfo()

@property (nonatomic, assign) QNZoneInfoType type;
@property (nonatomic, assign) QNZoneRegion zoneRegion;
@property (nonatomic, assign) long ttl;
@property (nonatomic, strong) NSDate *buildDate;
@property (nonatomic, strong) NSMutableArray<NSString *> *upDomainsList;
@property (nonatomic, strong) NSMutableDictionary *upDomainsDic;
@property (nonatomic, strong) NSDictionary *detailInfo;

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
    NSArray *urlDicList = [[NSArray alloc] initWithObjects:acc, src, old_acc, old_src, nil];
    NSMutableArray *domainList = [[NSMutableArray alloc] init];
    NSMutableDictionary *domainDic = [[NSMutableDictionary alloc] init];
    
    //main
    for (int i = 0; i < urlDicList.count; i++) {
        if ([[urlDicList[i] allKeys] containsObject:@"main"]) {
            NSArray *mainDomainList = urlDicList[i][@"main"];
            for (int i = 0; i < mainDomainList.count; i++) {
                [domainList addObject:mainDomainList[i]];
                [domainDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:mainDomainList[i]];
            }
        }
    }
    
    //backup
    for (int i = 0; i < urlDicList.count; i++) {
        if ([[urlDicList[i] allKeys] containsObject:@"backup"]) {
            NSArray *mainDomainList = urlDicList[i][@"backup"];
            for (int i = 0; i < mainDomainList.count; i++) {
                [domainList addObject:mainDomainList[i]];
                [domainDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:mainDomainList[i]];
            }
        }
    }
    
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
    
    QNZoneInfo *zoneInfo = [[QNZoneInfo alloc] init:ttl upDomainsList:domainList upDomainsDic:domainDic zoneRegion:zoneRegion];
    zoneInfo.acc = [QNUploadServerGroup buildInfoFromDictionary:acc];
    zoneInfo.src = [QNUploadServerGroup buildInfoFromDictionary:src];
    zoneInfo.old_acc = [QNUploadServerGroup buildInfoFromDictionary:old_acc];
    zoneInfo.old_src = [QNUploadServerGroup buildInfoFromDictionary:old_src];
    
    zoneInfo.detailInfo = detailInfo;
    
    return zoneInfo;
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
        QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:hosts[i]];
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
