//
//  QNZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class QNResponseInfo, QNUpToken, QNZonesInfo, QNUploadRegionRequestMetrics;

typedef void (^QNPrequeryReturn)(int code, QNResponseInfo * _Nullable httpResponseInfo, QNUploadRegionRequestMetrics * _Nullable metrics);

@interface QNZone : NSObject

/// 根据token查询相关Zone信息【内部使用】
/// @param token token信息
/// @param ret 查询回调
- (void)preQuery:(QNUpToken * _Nullable)token
              on:(QNPrequeryReturn)ret;

/// 根据token获取ZonesInfo 【内部使用】
/// @param token token信息
- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken * _Nullable)token;

@end

NS_ASSUME_NONNULL_END
