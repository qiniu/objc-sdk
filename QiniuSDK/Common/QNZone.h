//
//  QNZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"
#import "QNResponseInfo.h"
#import "QNUploadRequestMetrics.h"

NS_ASSUME_NONNULL_BEGIN

@class QNUpToken, QNZonesInfo, QNUploadRegionRequestMetrics;

typedef void (^QNPrequeryReturn)(int code, QNResponseInfo * _Nullable httpResponseInfo, QNUploadRegionRequestMetrics * _Nullable metrics);

@interface QNZone : NSObject

/**
 *    默认上传服务器地址列表
 */
- (void)preQuery:(QNUpToken * _Nullable)token
              on:(QNPrequeryReturn)ret;

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken * _Nullable)token;

@end

NS_ASSUME_NONNULL_END
