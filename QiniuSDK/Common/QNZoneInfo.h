//
//  QNZoneInfo.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    QNZoneRegion_z0,
    QNZoneRegion_z1,
    QNZoneRegion_z2,
    QNZoneRegion_as0,
    QNZoneRegion_na0,
    QNZoneRegion_unknown
} QNZoneRegion;

@interface QNUploadServerGroup : NSObject

@property(nonatomic,  copy, readonly)NSString *info;
@property(nonatomic, strong, readonly)NSArray <NSString *> *main;
@property(nonatomic, strong, readonly)NSArray <NSString *> *backup;
@property(nonatomic, strong, readonly)NSArray <NSString *> *allHosts;

+ (QNUploadServerGroup *)buildInfoFromDictionary:(NSDictionary *)dictionary;

@end

@interface QNZoneInfo : NSObject

@property (nonatomic, assign, readonly) long ttl;
@property(nonatomic, strong)QNUploadServerGroup *acc;
@property(nonatomic, strong)QNUploadServerGroup *src;
@property(nonatomic, strong)QNUploadServerGroup *old_acc;
@property(nonatomic, strong)QNUploadServerGroup *old_src;

@property(nonatomic, strong, readonly)NSArray <NSString *> *allHosts;
@property (nonatomic, strong, readonly) NSDictionary *detailInfo;

+ (QNZoneInfo *)zoneInfoWithMainHosts:(NSArray *)mainHosts
                              ioHosts:(NSArray * _Nullable)ioHosts;
+ (QNZoneInfo *)zoneInfoFromDictionary:(NSDictionary *)detailInfo;

- (BOOL)isValid;

@end

@interface QNZonesInfo : NSObject

@property (nonatomic, strong) NSArray<QNZoneInfo *> *zonesInfo;

+ (instancetype)infoWithDictionary:(NSDictionary *)dictionary;

- (instancetype)initWithZonesInfo:(NSArray<QNZoneInfo *> *)zonesInfo;

@end

NS_ASSUME_NONNULL_END
