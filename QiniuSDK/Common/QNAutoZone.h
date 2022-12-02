//
//  QNAutoZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZone.h"

NS_ASSUME_NONNULL_BEGIN

@class QNFixedZone;
@interface QNAutoZone : QNZone

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts;

+ (void)clearCache;

/**
 * 当 查询失败时，会使用 zones 进行上传，默认不配置。
 */
- (void)setDefaultZones:(NSArray <QNFixedZone *> *)zones;

@end

NS_ASSUME_NONNULL_END
