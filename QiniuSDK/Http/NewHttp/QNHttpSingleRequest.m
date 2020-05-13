//
//  QNHttpRequest+SingleRequestRetry.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import "QNHttpSingleRequest.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "QNResponseInfo.h"
#import "QNRequestClient.h"
#import "QNUploadRequstState.h"

#import "QNUploadSystemClient.h"
#import "NSURLRequest+QNRequest.h"

@interface QNHttpSingleRequest()

@property(nonatomic, assign)int currentRetryTime;
@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequstState *requestState;

@property(nonatomic, strong)id <QNRequestClient> client;

@end
@implementation QNHttpSingleRequest

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  requestState:(QNUploadRequstState *)requestState{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _requestState = requestState;
        _currentRetryTime = 0;
    }
    return self;
}

- (void)request:(NSURLRequest *)request
      isSkipDns:(BOOL)isSkipDns
    shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(void (^)(QNResponseInfo * _Nullable, NSDictionary * _Nullable))complete{
    
    _currentRetryTime = 0;
    [self retryRquest:request isSkipDns:isSkipDns shouldRetry:shouldRetry progress:progress complete:complete];
}

- (void)retryRquest:(NSURLRequest *)request
          isSkipDns:(BOOL)isSkipDns
        shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(void (^)(QNResponseInfo * _Nullable, NSDictionary * _Nullable))complete{
    
    if (isSkipDns && kQNGloableConfiguration.isDnsOpen) {
        self.client = [[QNUploadSystemClient alloc] init];
    } else {
        self.client = [[QNUploadSystemClient alloc] init];
    }
    
    NSLog(@"== request host:%@ / %@", request.URL.host, request.qn_domain);
    
    __weak typeof(self) weakSelf = self;
    BOOL (^checkCancelHandler)(void) = ^{
        BOOL isCancel = weakSelf.requestState.isUserCancel;
        if (!isCancel && weakSelf.uploadOption.cancellationSignal) {
            isCancel = weakSelf.uploadOption.cancellationSignal();
        }
        return isCancel;
    };
    
    [self.client request:request connectionProxy:self.config.proxy progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        
        if (checkCancelHandler()) {
            weakSelf.requestState.isUserCancel = YES;
            [weakSelf.client cancel];
        } else if (progress) {
            progress(totalBytesWritten, totalBytesExpectedToWrite);
        }
        
    } complete:^(NSURLResponse *response, QNUploadSingleRequestMetrics *metrics, NSData * responseData, NSError * error) {
        
        QNResponseInfo *responseInfo = nil;
        if (checkCancelHandler()) {
            if (complete) {
                responseInfo = [QNResponseInfo cancelResponse];
                responseInfo.requestMetrics = metrics;
                complete(responseInfo, nil);
            }
            return;
        }
        
        NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:responseData
                                                                    options:NSJSONReadingMutableLeaves
                                                                      error:nil];
        responseInfo = [[QNResponseInfo alloc] initWithResponseInfoHost:request.qn_domain
                                                              response:(NSHTTPURLResponse *)response
                                                                  body:responseData
                                                                 error:error];
        responseInfo.requestMetrics = metrics;
        if (shouldRetry(responseInfo, responseDic)
            && self.currentRetryTime < self.config.retryMax
            && responseInfo.couldHostRetry) {
            self.currentRetryTime += 1;
            QNAsyncRunAfter(self.config.retryInterval, kQNBackgroundQueue, ^{
                [self retryRquest:request isSkipDns:isSkipDns shouldRetry:shouldRetry progress:progress complete:complete];
            });
        } else {
            if (complete) {
                complete(responseInfo, responseDic);
            }
        }
    }];
    
}

@end
