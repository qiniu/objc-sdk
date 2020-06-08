//
//  QNZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"
#import "QNHttpResponseInfo.h"
NS_ASSUME_NONNULL_BEGIN

@class QNUpToken, QNZonesInfo;

typedef void (^QNPrequeryReturn)(int code, QNHttpResponseInfo * _Nullable httpResponseInfo);

@interface QNZone : NSObject

- (NSString *)upHost:(QNZoneInfo *)zoneInfo
             isHttps:(BOOL)isHttps
          lastUpHost:(NSString *)lastUpHost;
/**
 *    默认上传服务器地址列表
 */
- (void)preQuery:(QNUpToken * _Nullable)token
              on:(QNPrequeryReturn)ret;

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken * _Nullable)token;

- (NSString *)up:(QNUpToken * _Nullable)token
    zoneInfoType:(QNZoneInfoType)zoneInfoType
         isHttps:(BOOL)isHttps
    frozenDomain:(NSString * _Nullable)frozenDomain;

@end

NS_ASSUME_NONNULL_END
