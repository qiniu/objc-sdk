//
//  QNHttpRequest.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRegion.h"

NS_ASSUME_NONNULL_BEGIN


@class QNUploadRequstState, QNResponseInfo, QNConfiguration, QNUploadOption;

@interface QNHttpRequest : NSObject

@property(nonatomic, strong, readonly)QNConfiguration *config;
@property(nonatomic, strong, readonly)QNUploadOption *uploadOption;


- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  requestState:(QNUploadRequstState *)requestState;


- (void)get:(id <QNUploadServer> _Nullable)server
     action:(NSString * _Nullable)action
    headers:(NSDictionary * _Nullable)headers
   complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete;

- (void)post:(id <QNUploadServer> _Nullable)server
      action:(NSString * _Nullable)action
     headers:(NSDictionary * _Nullable)headers
        body:(NSData * _Nullable)body
    progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete;

@end

NS_ASSUME_NONNULL_END
