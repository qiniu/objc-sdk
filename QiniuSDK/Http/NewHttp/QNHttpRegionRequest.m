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

#import "QNResponseInfo.h"
#import "QNHttpSingleRequest.h"

@interface QNHttpRegionRequest()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequstState *requestState;

@property(nonatomic, strong)QNHttpSingleRequest *singleRetry;

// old server 不验证tls sni
@property(nonatomic, assign)BOOL isUseOldServer;
@property(nonatomic, strong)id <QNUploadServer> currentServer;
@property(nonatomic, strong)id <QNUploadRegion> region;

@end
@implementation QNHttpRegionRequest

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                        region:(id <QNUploadRegion>)region
                  requestState:(QNUploadRequstState *)requestState{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _region = region;
        _requestState = requestState;
        _singleRetry = [[QNHttpSingleRequest alloc] initWithConfig:config
                                                           uploadOption:uploadOption
                                                           requestState:requestState];
    }
    return self;
}

- (void)get:(NSString *)action
    headers:(NSDictionary *)headers
   shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
   complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
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
    complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
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
              complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    QNResponseInfo *errorResponseInfo = [self checkServer:server];
    if (errorResponseInfo) {
        complete(errorResponseInfo, nil);
        return;
    }
    
    NSString *serverHost = server.host;
    NSString *serverIP = server.ip;
    if (!serverHost && serverHost.length == 0) {
        return;
    }
    
    if (self.config.converter) {
        serverHost = self.config.converter(serverHost);
        serverIP = nil;
    }
    
    self.currentServer = server;
    
    BOOL isSkipDns = NO;
    NSString *scheme = self.config.useHttps ? @"https://" : @"http://";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    if (server.ip && server.ip.length > 0) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@", scheme, serverIP, action ?: @""];
        request.URL = [NSURL URLWithString:urlString];
        request.qn_domain = serverHost;
        isSkipDns = YES;
    } else {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@", scheme, serverHost, action ?: @""];
        request.URL = [NSURL URLWithString:urlString];
        request.qn_domain = serverHost;
        isSkipDns = NO;
    }
    request.HTTPMethod = method;
    [request setAllHTTPHeaderFields:headers];
    [request setTimeoutInterval:self.config.timeoutInterval];
    request.HTTPBody = body;
    [self.singleRetry request:request isSkipDns:isSkipDns shouldRetry:shouldRetry progress:progress complete:^(QNResponseInfo * responseInfo, NSDictionary * response) {
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
                complete(responseInfo, response);
            }
        } else if (complete) {
            complete(responseInfo, response);
        }
    }];
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

- (QNResponseInfo *)checkServer:(id <QNUploadServer>)server{
    QNResponseInfo *responseInfo = nil;
    if (!server.host || server.host.length == 0) {
        responseInfo = [QNResponseInfo responseInfoWithInvalidArgument:@"server error"];
    }
    return responseInfo;
}

@end
