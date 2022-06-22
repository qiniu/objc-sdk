//
//  QNFixZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNFixedZone : QNZone

/**
 *    zone 0 华东
 *
 *    @return 实例
 */
+ (instancetype)zone0;

/**
 *    zoneCnEast2 华东-浙江2
 *
 *    @return 实例
 */
+ (instancetype)zoneCnEast2;

/**
 *    zone 1 华北
 *
 *    @return 实例
 */
+ (instancetype)zone1;

/**
 *    zone 2 华南
 *
 *    @return 实例
 */
+ (instancetype)zone2;

/**
 *    zoneNorthEast1 首尔区域
 *
 *    @return 实例
 */
+ (instancetype)zoneNorthEast1;

/**
 *    zone Na0 北美
 *
 *    @return 实例
 */
+ (instancetype)zoneNa0;

/**
 *    zone As0 新加坡
 *
 *    @return 实例
 */
+ (instancetype)zoneAs0;

/**
 *    zone fog-cn-east-1 雾存储 华东-1
 *    分片上传暂时仅支持分片 api v2
 *    分片 api v2设置方式：配置 QNConfiguration 的 resumeUploadVersion 为 QNResumeUploadVersionV2
 *    eg：
 *    QNConfiguration *configuration = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
 *          builder.resumeUploadVersion = QNResumeUploadVersionV2;
 *    }];
 *
 *    @return 实例
 */
+ (instancetype)zoneFogCnEast1;

/**
 *    Zone初始化方法
 *
 *    @param upList     默认上传服务器地址列表
 *    @return Zone实例
 */
- (instancetype)initWithUpDomainList:(NSArray<NSString *> *)upList;

/**
 *    Zone初始化方法
 *
 *    @param upList     默认上传服务器地址列表
 *
 *    @return Zone实例
 */
+ (instancetype)createWithHost:(NSArray<NSString *> *)upList;

/**
 *   获取本地所有固定zone信息
 */
+ (QNFixedZone *)localsZoneInfo;

@end

NS_ASSUME_NONNULL_END
