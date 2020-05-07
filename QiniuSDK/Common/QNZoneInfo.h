//
//  QNZoneInfo.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, QNZoneInfoType) {
    QNZoneInfoTypeMain,
    QNZoneInfoTypeBackup,
};
typedef enum : NSUInteger {
    QNZoneRegion_z0,
    QNZoneRegion_z1,
    QNZoneRegion_z2,
    QNZoneRegion_as0,
    QNZoneRegion_na0,
    QNZoneRegion_unknown
} QNZoneRegion;

@interface QNUploadServerGroup : NSObject

@property(nonatomic,  copy)NSString *info;
@property(nonatomic, strong)NSArray <NSString *> *main;
@property(nonatomic, strong)NSArray <NSString *> *backup;

+ (QNUploadServerGroup *)buildInfoFromDictionary:(NSDictionary *)dictionary;

@end

@interface QNZoneInfo : NSObject

@property (nonatomic, assign, readonly) QNZoneInfoType type;
@property (nonatomic, assign, readonly) long ttl;

@property (nonatomic, strong, readonly) NSArray<NSString *> *upDomainsList;
@property (nonatomic, strong, readonly) NSMutableDictionary *upDomainsDic;

@property(nonatomic, strong)QNUploadServerGroup *acc;
@property(nonatomic, strong)QNUploadServerGroup *src;
@property(nonatomic, strong)QNUploadServerGroup *old_acc;
@property(nonatomic, strong)QNUploadServerGroup *old_src;

- (instancetype)init:(long)ttl
       upDomainsList:(NSMutableArray<NSString *> *)upDomainsList
        upDomainsDic:(NSMutableDictionary *)upDomainsDic
          zoneRegion:(QNZoneRegion)zoneRegion;

- (QNZoneInfo *)buildInfoFromJson:(NSDictionary *)resp;

- (void)frozenDomain:(NSString *)domain;

- (BOOL)isValid;

@end

@interface QNZonesInfo : NSObject

@property (nonatomic, strong) NSArray<QNZoneInfo *> *zonesInfo;

@property (nonatomic, assign, readonly) BOOL hasBackupZone;

+ (instancetype)buildZonesInfoWithResp:(NSDictionary *)resp;

- (instancetype)initWithZonesInfo:(NSArray<QNZoneInfo *> *)zonesInfo;

- (QNZoneInfo *)getZoneInfoWithType:(QNZoneInfoType)type;

- (NSString *)getZoneInfoRegionNameWithType:(QNZoneInfoType)type;

@end

NS_ASSUME_NONNULL_END
