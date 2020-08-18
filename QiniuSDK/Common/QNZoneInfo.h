//
//  QNZoneInfo.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadServerGroup : NSObject

@property(nonatomic,  copy, readonly)NSString *info;
@property(nonatomic, strong, readonly)NSArray <NSString *> *main;
@property(nonatomic, strong, readonly)NSArray <NSString *> *backup;
@property(nonatomic, strong, readonly)NSArray <NSString *> *allHosts;

/// 根据键值对构造对象 【内部使用】
/// @param dictionary 键值对信息
+ (QNUploadServerGroup *)buildInfoFromDictionary:(NSDictionary *)dictionary;

@end


extern NSString *const QNZoneInfoSDKDefaultIOHost;
extern NSString *const QNZoneInfoEmptyRegionId;

@interface QNZoneInfo : NSObject

@property (nonatomic, assign, readonly) long ttl;
@property(nonatomic, strong)QNUploadServerGroup *acc;
@property(nonatomic, strong)QNUploadServerGroup *src;
@property(nonatomic, strong)QNUploadServerGroup *old_acc;
@property(nonatomic, strong)QNUploadServerGroup *old_src;

@property(nonatomic,   copy, readonly)NSString *regionId;
@property(nonatomic, strong, readonly)NSArray <NSString *> *allHosts;
@property(nonatomic, strong, readonly)NSDictionary *detailInfo;

+ (QNZoneInfo *)zoneInfoWithMainHosts:(NSArray <NSString *> *)mainHosts
                              ioHosts:(NSArray <NSString *> * _Nullable)ioHosts;

+ (QNZoneInfo *)zoneInfoWithMainHosts:(NSArray <NSString *> *)mainHosts
                             oldHosts:(NSArray <NSString *> * _Nullable)oldHosts
                              ioHosts:(NSArray <NSString *> * _Nullable)ioHosts;

/// 根据键值对构造对象 【内部使用】
/// @param detailInfo 键值对信息
+ (QNZoneInfo *)zoneInfoFromDictionary:(NSDictionary *)detailInfo;

- (BOOL)isValid;

@end

@interface QNZonesInfo : NSObject

@property (nonatomic, strong) NSArray<QNZoneInfo *> *zonesInfo;

/// 根据键值对构造对象 【内部使用】
/// @param dictionary 键值对信息
+ (instancetype)infoWithDictionary:(NSDictionary *)dictionary;

- (instancetype)initWithZonesInfo:(NSArray<QNZoneInfo *> *)zonesInfo;

@end

NS_ASSUME_NONNULL_END
