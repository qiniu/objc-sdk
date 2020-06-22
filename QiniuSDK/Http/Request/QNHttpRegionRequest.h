//
//  QNHttpRequest.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNHttpSingleRequest.h"
#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN


@class QNUploadRequestState, QNResponseInfo, QNConfiguration, QNUploadOption, QNUpToken, QNUploadRegionRequestMetrics;

typedef void(^QNRegionRequestCompleteHandler)(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response);

@interface QNHttpRegionRequest : NSObject

@property(nonatomic, strong, readonly)QNConfiguration *config;
@property(nonatomic, strong, readonly)QNUploadOption *uploadOption;


- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         token:(QNUpToken *)token
                        region:(id <QNUploadRegion>)region
                   requestInfo:(QNUploadRequestInfo *)requestInfo
                  requestState:(QNUploadRequestState *)requestState;


- (void)get:(NSString * _Nullable)action
    headers:(NSDictionary * _Nullable)headers
shouldRetry:(BOOL(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
   complete:(QNRegionRequestCompleteHandler)complete;

- (void)post:(NSString * _Nullable)action
     headers:(NSDictionary * _Nullable)headers
        body:(NSData * _Nullable)body
 shouldRetry:(BOOL(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
    progress:(void(^_Nullable)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(QNRegionRequestCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
