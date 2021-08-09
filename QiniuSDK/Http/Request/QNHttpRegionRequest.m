//
//  QNHttpRequest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNLogUtil.h"
#import "QNAsyncRun.h"
#import "QNUploadRequestState.h"
#import "QNHttpRegionRequest.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "NSURLRequest+QNRequest.h"

#import "QNUploadRequestMetrics.h"
#import "QNResponseInfo.h"

@interface QNHttpRegionRequest()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequestInfo *requestInfo;
@property(nonatomic, strong)QNUploadRequestState *requestState;

@property(nonatomic, strong)QNUploadRegionRequestMetrics *requestMetrics;
@property(nonatomic, strong)QNHttpSingleRequest *singleRequest;

@property(nonatomic, strong)id <QNUploadServer> currentServer;
@property(nonatomic, strong)id <QNUploadRegion> region;

@end
@implementation QNHttpRegionRequest

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         token:(QNUpToken *)token
                        region:(id <QNUploadRegion>)region
                   requestInfo:(QNUploadRequestInfo *)requestInfo
                  requestState:(QNUploadRequestState *)requestState {
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _region = region;
        _requestInfo = requestInfo;
        _requestState = requestState;
        _singleRequest = [[QNHttpSingleRequest alloc] initWithConfig:config
                                                        uploadOption:uploadOption
                                                               token:token
                                                         requestInfo:requestInfo
                                                        requestState:requestState];
    }
    return self;
}

- (void)get:(NSString *)action
    headers:(NSDictionary *)headers
shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
   complete:(QNRegionRequestCompleteHandler)complete{
    
    self.requestMetrics = [[QNUploadRegionRequestMetrics alloc] initWithRegion:self.region];
    [self.requestMetrics start];
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"GET"
                    body:nil
             shouldRetry:shouldRetry
                progress:nil
                complete:complete];
}

- (void)post:(NSString *)action
     headers:(NSDictionary *)headers
        body:(NSData *)body
 shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
    progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(QNRegionRequestCompleteHandler)complete{
    
    self.requestMetrics = [[QNUploadRegionRequestMetrics alloc] initWithRegion:self.region];
    [self.requestMetrics start];
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"POST"
                    body:body
             shouldRetry:shouldRetry
                progress:progress
                complete:complete];
}


- (void)put:(NSString *)action
    headers:(NSDictionary *)headers
       body:(NSData *)body
shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
   progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
   complete:(QNRegionRequestCompleteHandler)complete{
    
    self.requestMetrics = [[QNUploadRegionRequestMetrics alloc] initWithRegion:self.region];
    [self.requestMetrics start];
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"PUT"
                    body:body
             shouldRetry:shouldRetry
                progress:progress
                complete:complete];
}


- (void)performRequest:(id <QNUploadServer>)server
                action:(NSString *)action
               headers:(NSDictionary *)headers
                method:(NSString *)method
                  body:(NSData *)body
           shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRegionRequestCompleteHandler)complete{
    
    if (!server.host || server.host.length == 0) {
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithSDKInteriorError:@"server error"];
        [self complete:responseInfo response:nil complete:complete];
        return;
    }
    
    NSString *serverHost = server.host;
    NSString *serverIP = server.ip;
    
    if (self.config.converter) {
        serverHost = self.config.converter(serverHost);
        serverIP = nil;
    }
    
    self.currentServer = server;
    
    BOOL toSkipDns = NO;
    NSString *scheme = self.config.useHttps ? @"https://" : @"http://";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    if (serverIP && serverIP.length > 0) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@", scheme, serverIP, action ?: @""];
        request.URL = [NSURL URLWithString:urlString];
        request.qn_domain = serverHost;
        request.qn_ip = serverIP;
        toSkipDns = YES;
    } else {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@", scheme, serverHost, action ?: @""];
        request.URL = [NSURL URLWithString:urlString];
        request.qn_domain = serverHost;
        request.qn_ip = nil;
        toSkipDns = NO;
    }
    request.HTTPMethod = method;
    [request setAllHTTPHeaderFields:headers];
    [request setTimeoutInterval:self.config.timeoutInterval];
    request.HTTPBody = body;
    
    QNLogInfo(@"key:%@ url:%@", self.requestInfo.key, request.URL);
    QNLogInfo(@"key:%@ headers:%@", self.requestInfo.key, headers);
    
    kQNWeakSelf;
    [self.singleRequest request:request
                         server:server
                    shouldRetry:shouldRetry
                       progress:progress
                       complete:^(QNResponseInfo * _Nullable responseInfo, NSArray<QNUploadSingleRequestMetrics *> * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        [self.requestMetrics addMetricsList:metrics];
        
        if (shouldRetry(responseInfo, response)
            && self.config.allowBackupHost
            && responseInfo.couldRegionRetry) {
            
            id <QNUploadServer> newServer = [self getNextServer:responseInfo];
            if (newServer) {
                QNAsyncRunAfter(self.config.retryInterval, kQNBackgroundQueue, ^{
                    [self performRequest:newServer
                                  action:action
                                 headers:headers
                                  method:method
                                    body:body
                             shouldRetry:shouldRetry
                                progress:progress
                                complete:complete];
                });
            } else if (complete) {
                [self complete:responseInfo response:response complete:complete];
            }
        } else if (complete) {
            [self complete:responseInfo response:response complete:complete];
        }
    }];
    
}

- (void)complete:(QNResponseInfo *)responseInfo
        response:(NSDictionary *)response
        complete:(QNRegionRequestCompleteHandler)completionHandler {
    [self.requestMetrics end];
    
    if (completionHandler) {
        completionHandler(responseInfo, self.requestMetrics, response);
    }
    self.singleRequest = nil;
}

//MARK: --
- (id <QNUploadServer>)getNextServer:(QNResponseInfo *)responseInfo{

    if (responseInfo.isTlsError) {
        self.requestState.isUseOldServer = YES;
    }
    
    return [self.region getNextServer:[self.requestState copy] responseInfo:responseInfo freezeServer:self.currentServer];
}

@end
