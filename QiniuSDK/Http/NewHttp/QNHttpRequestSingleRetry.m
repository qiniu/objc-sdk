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
#import "QNRequestClient.h"
#import "QNUploadRequstState.h"

#import "QNUploadSystemClient.h"
#import "NSURLRequest+QNRequest.h"

@interface QNHttpRequestSingleRetry()

@property(nonatomic, assign)int currentRetryTime;
@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequstState *requestState;

@property(nonatomic, strong)id <QNRequestClient> client;

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
    
    if (isSkipDns && kQNGloableConfiguration.isDnsOpen) {
        self.client = [[QNUploadSystemClient alloc] init];
    } else {
        self.client = [[QNUploadSystemClient alloc] init];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.client request:request connectionProxy:self.config.proxy progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        
        BOOL isCancel = self.requestState.isUserCancel;
        if (!isCancel && self.uploadOption.cancellationSignal) {
            isCancel = self.uploadOption.cancellationSignal();
        }
        if (isCancel) {
            [weakSelf.client cancel];
            self.requestState.isUserCancel = YES;
        } else if (progress) {
            progress(totalBytesWritten, totalBytesExpectedToWrite);
        }
        
    } complete:^(NSURLResponse *response, NSData * responseData, NSError * error) {
        
        QNResponseInfo *reponseInfo = nil;
        BOOL isCancel = self.requestState.isUserCancel;
        if (!isCancel && self.uploadOption.cancellationSignal) {
            isCancel = self.uploadOption.cancellationSignal();
        }
        if (isCancel) {
            if (complete) {
                reponseInfo = [QNResponseInfo cancelWithDuration:0];
                complete(reponseInfo, nil);
            }
            return;
        }
        
        if ([reponseInfo isOK] == false && [reponseInfo couldRetry] && self.currentRetryTime < self.config.retryMax) {
            self.currentRetryTime += 1;
            [self retryRquest:request isSkipDns:isSkipDns progress:progress complete:complete];
        } else {
            if (complete) {
                NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:responseData
                                                                            options:NSJSONReadingMutableLeaves
                                                                              error:nil];
                reponseInfo = [[QNResponseInfo alloc] initWithResponseInfoHost:request.qn_domain
                                                                      response:(NSHTTPURLResponse *)response
                                                                          body:responseData
                                                                         error:error];
                complete(reponseInfo, responseDic);
            }
        }
    }];
    
}

@end
