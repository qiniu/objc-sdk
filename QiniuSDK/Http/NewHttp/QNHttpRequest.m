//
//  QNHttpRequest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNHttpRequest.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"

#import "NSURLRequest+QNRequest.h"

#import "QNResponseInfo.h"
#import "QNHttpRequestSingleRetry.h"

@interface QNHttpRequest()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequstState *requestState;

@property(nonatomic, strong)QNHttpRequestSingleRetry *singleRetry;

@end
@implementation QNHttpRequest

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  requestState:(QNUploadRequstState *)requestState{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _requestState = requestState;
        _singleRetry = [[QNHttpRequestSingleRetry alloc] initWithConfig:config
                                                           uploadOption:uploadOption
                                                           requestState:requestState];
    }
    return self;
}

- (void)get:(id <QNUploadServer>)server
     action:(NSString *)action
    headers:(NSDictionary *)headers
   complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    [self performRequest:server
                  action:action
                 headers:headers
                  method:@"GET"
                    body:nil
                progress:nil
                complete:complete];
}

- (void)post:(id <QNUploadServer>)server
      action:(NSString *)action
     headers:(NSDictionary *)headers
        body:(NSData *)body
    progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    [self performRequest:server
                  action:action
                 headers:headers
                  method:@"POST"
                    body:body
                progress:progress
                complete:complete];
}


- (void)performRequest:(id <QNUploadServer>)server
                action:(NSString *)action
               headers:(NSDictionary *)headers
                method:(NSString *)method
                  body:(NSData *)body
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    NSString *serverHost = server.host;
    NSString *serverIP = server.ip;
    if (!serverHost && serverHost.length == 0) {
        return;
    }
    
    BOOL isSkipDns = NO;
    NSString *scheme = self.config.useHttps ? @"https://" : @"http://";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    if (server.ip && server.ip.copy > 0) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@", scheme, serverIP, action];
        request.URL = [NSURL URLWithString:urlString];
        request.qn_domain = serverHost;
        isSkipDns = YES;
    } else {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@", scheme, serverHost, action];
        request.URL = [NSURL URLWithString:urlString];
        isSkipDns = NO;
    }
    request.HTTPMethod = method;
    [request setAllHTTPHeaderFields:headers];
    
    [self.singleRetry request:request isSkipDns:isSkipDns progress:progress complete:^(QNResponseInfo * responseInfo, NSDictionary * response) {
        if (complete) {
            complete(responseInfo, response);
        }
    }];
}




@end
