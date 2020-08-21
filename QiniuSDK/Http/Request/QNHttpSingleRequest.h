//
//  QNHttpRequest+SingleRequestRetry.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRequestInfo.h"
#import "QNIUploadServer.h"

NS_ASSUME_NONNULL_BEGIN

@class QNUploadRequestState, QNResponseInfo, QNConfiguration, QNUploadOption, QNUpToken, QNUploadSingleRequestMetrics;

typedef void(^QNSingleRequestCompleteHandler)(QNResponseInfo * _Nullable responseInfo, NSArray <QNUploadSingleRequestMetrics *> * _Nullable metrics, NSDictionary * _Nullable response);

@interface QNUploadRequestState : NSObject

@property(atomic, assign)BOOL isUserCancel;

@end


@interface QNHttpSingleRequest : NSObject

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         token:(QNUpToken *)token
                   requestInfo:(QNUploadRequestInfo *)requestInfo
                  requestState:(QNUploadRequestState *)requestState;


/// 网络请求
/// @param request 请求内容
/// @param server server信息，目前仅用于日志统计
/// @param toSkipDns 请求是否需要跳过Dns 当请求的中配置了IP即可跳过 反之不跳过
/// @param shouldRetry 判断是否需要重试的block
/// @param progress 上传进度回调
/// @param complete 上传完成回调
- (void)request:(NSURLRequest *)request
         server:(id <QNUploadServer>)server
      toSkipDns:(BOOL)toSkipDns
    shouldRetry:(BOOL(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(QNSingleRequestCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
