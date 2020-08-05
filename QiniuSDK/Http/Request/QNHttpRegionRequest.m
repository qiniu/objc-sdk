//
//  QNHttpRequest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import "QNHttpRegionRequest.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "NSURLRequest+QNRequest.h"

#import "QNUploadRequestMetrics.h"
#import "QNResponseInfo.h"

@interface QNHttpRegionRequest()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequestState *requestState;

@property(nonatomic, strong)QNUploadRegionRequestMetrics *requestMetrics;
@property(nonatomic, strong)QNHttpSingleRequest *singleRequest;

// old server 不验证tls sni
@property(nonatomic, assign)BOOL isUseOldServer;
@property(nonatomic, strong)id <QNUploadServer> currentServer;
@property(nonatomic, strong)id <QNUploadRegion> region;

@end
@implementation QNHttpRegionRequest

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         token:(QNUpToken *)token
                        region:(id <QNUploadRegion>)region
                   requestInfo:(QNUploadRequestInfo *)requestInfo
                  requestState:(QNUploadRequestState *)requestState{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _region = region;
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
    [self performRequest:[self getNextServer:nil]
                  action:action
                 headers:headers
                  method:@"POST"
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
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithInvalidArgument:@"server error"];
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
    [self.singleRequest request:request
                         server:server
                      toSkipDns:toSkipDns
                    shouldRetry:shouldRetry
                       progress:progress
                       complete:^(QNResponseInfo * _Nullable responseInfo, NSArray<QNUploadSingleRequestMetrics *> * _Nullable metrics, NSDictionary * _Nullable response) {
        
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

    if (completionHandler) {
        completionHandler(responseInfo, self.requestMetrics, response);
    }
}

//MARK: --
- (id <QNUploadServer>)getNextServer:(QNResponseInfo *)responseInfo{

    if (responseInfo == nil) {
        return [self.region getNextServer:NO freezeServer:nil];
    }
    
    if (responseInfo.isTlsError == YES) {
        self.isUseOldServer = YES;
    }
    return [self.region getNextServer:self.isUseOldServer freezeServer:self.currentServer];
}

@end
