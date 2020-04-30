//
//  QNHttpRequest+SingleRequestRetry.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNHttpRequestSingleRetry.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "QNResponseInfo.h"
#import "QNRequestClientAble.h"
#import "QNUploadRequstState.h"

@interface QNHttpRequestSingleRetry()

@property(nonatomic, assign)int currentRetryTime;
@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequstState *requestState;

@property(nonatomic, strong)id <QNRequestClientAble> systemClient;
@property(nonatomic, strong)id <QNRequestClientAble> libCurlClient;

@end
@implementation QNHttpRequestSingleRetry

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
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(void (^)(QNResponseInfo * _Nullable, NSDictionary * _Nullable))complete{
    
    _currentRetryTime = 0;
    [self retryRquest:request isSkipDns:isSkipDns progress:progress complete:complete];
}

- (void)retryRquest:(NSURLRequest *)request
          isSkipDns:(BOOL)isSkipDns
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(void (^)(QNResponseInfo * _Nullable, NSDictionary * _Nullable))complete{
    
    id <QNRequestClientAble> client = nil;
    if (isSkipDns && kQNGloableConfiguration.isDnsOpen) {
        client = self.libCurlClient;
    } else {
        client = self.systemClient;
    }
    
    __weak typeof(client) weakClient = client;
    [client request:request progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        
        BOOL isCancel = self.requestState.isUserCancel;
        if (!isCancel && self.uploadOption.cancellationSignal) {
            isCancel = self.uploadOption.cancellationSignal();
        }
        if (isCancel) {
            [weakClient cancel];
            self.requestState.isUserCancel = YES;
        } else if (progress) {
            progress(totalBytesWritten, totalBytesExpectedToWrite);
        }
        
    } complete:^(NSDictionary * _Nullable response, NSError * _Nullable error, id<QNRequestTransactionAble>  _Nonnull transaction) {
        
        QNResponseInfo *reponseInfo = nil;
        BOOL isCancel = self.requestState.isUserCancel;
        if (!isCancel && self.uploadOption.cancellationSignal) {
            isCancel = self.uploadOption.cancellationSignal();
        }
        if (isCancel) {
            if (complete) {
                complete(reponseInfo, response);
            }
            return;
        }
        
        if ([reponseInfo isOK] == false && [reponseInfo couldRetry] && self.currentRetryTime < self.config.retryMax) {
            self.currentRetryTime += 1;
            [self retryRquest:request isSkipDns:isSkipDns progress:progress complete:complete];
        } else {
            if (complete) {
                complete(reponseInfo, response);
            }
        }
    }];
    
}

@end
