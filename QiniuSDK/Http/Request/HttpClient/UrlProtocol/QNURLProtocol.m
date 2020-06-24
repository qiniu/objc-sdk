//
//  QNURLProtocol.m
//  AppTest
//
//  Created by yangsen on 2020/4/7.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNURLProtocol.h"
#import "QNCFHttpClient.h"
#import "NSURLRequest+QNRequest.h"
#import "NSObject+QNSwizzle.h"
#import <objc/runtime.h>

@interface QNRequestInfo : NSObject
@property(nonatomic, weak)NSURLSession *session;
@property(nonatomic, weak)NSURLSessionDataTask *task;
@end
@implementation QNRequestInfo
@end

@interface QNRequestInfoManager : NSObject
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNRequestInfo *> *infos;
@end
@implementation QNRequestInfoManager
+ (instancetype)share{
    static QNRequestInfoManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNRequestInfoManager alloc] init];
        [manager setupData];
    });
    return manager;
}
- (void)setupData{
    _infos = [NSMutableDictionary dictionary];
}
- (void)setRequestInfo:(QNRequestInfo *)info forRequest:(NSURLRequest *)request{
    NSString *requestIdentifier = [request qn_identifier];
    if (!requestIdentifier || !info) {
        return;
    }
    @synchronized (self) {
        [self.infos setObject:info forKey:requestIdentifier];
    }
}
- (void)removeRequestInfoForRequest:(NSURLRequest *)request{
    NSString *requestIdentifier = [request qn_identifier];
    if (!requestIdentifier) {
        return;
    }
    @synchronized (self) {
        [self.infos removeObjectForKey:requestIdentifier];
    }
}
- (QNRequestInfo *)getRequestInfoForRequest:(NSURLRequest *)request{
    NSString *requestIdentifier = [request qn_identifier];
    if (!requestIdentifier) {
        return nil;
    }
    
    QNRequestInfo *info = nil;
    @synchronized (self) {
        info = self.infos[requestIdentifier];
    }
    return info;
}

@end



@interface NSURLRequest(QNHttps)
@property(nonatomic, readonly)NSURLSession *qn_session;
@property(nonatomic, readonly)NSURLSessionDataTask *qn_task;
@end
@implementation NSURLRequest(QNHttps)
- (NSURLSession *)qn_session{
    return [[QNRequestInfoManager share] getRequestInfoForRequest:self].session;
}
- (NSURLSessionDataTask *)qn_task{
    return [[QNRequestInfoManager share] getRequestInfoForRequest:self].task;
}
- (void)qn_setSession:(NSURLSession *)session task:(NSURLSessionDataTask *)task{
    QNRequestInfo *info = [[QNRequestInfo alloc] init];
    info.session = session;
    info.task = task;
    [[QNRequestInfoManager share] setRequestInfo:info forRequest:self];
}
- (void)qn_requestRemoveTask{
    [[QNRequestInfoManager share] removeRequestInfoForRequest:self];
}
- (BOOL)qnHttps_shouldInit{
    if ([self qn_isQiNiuRequest] && self.qn_ip.length > 0
        && ([self.URL.absoluteString hasPrefix:@"http://"] || [self.URL.absoluteString hasPrefix:@"https://"])) {
        return YES;
    } else {
        return NO;
    }
}
@end


@interface NSURLSession(QNURLProtocol)
@end
@implementation NSURLSession(QNURLProtocol)

+ (void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self qn_swizzleInstanceMethodsOfSelectorA:@selector(dataTaskWithRequest:)
                                         selectorB:@selector(qn_dataTaskWithRequest:)];
    });
}
- (NSURLSessionDataTask *)qn_dataTaskWithRequest:(NSURLRequest *)request{
    NSURLSessionDataTask *task = [self qn_dataTaskWithRequest:request];
    if ([request qn_isQiNiuRequest]) {
        [request qn_setSession:self task:task];
    }
    return task;
}
@end



@interface QNURLProtocol()<QNCFHttpClientDelegate>

@property(nonatomic, strong)QNCFHttpClient *httpsClient;

@end
@implementation QNURLProtocol

#define kQNRequestIdentifiers @"QNRequestIdentifiers"

+ (void)registerProtocol{
    [NSURLProtocol registerClass:[QNURLProtocol class]];
}

+ (void)unregisterProtocol{
    [NSURLProtocol unregisterClass:[QNURLProtocol class]];
}

//MARK: -- overload
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {

    if ([NSURLProtocol propertyForKey:kQNRequestIdentifiers inRequest:request]) {
        return NO;
    }
    if ([request qnHttps_shouldInit]) {
        return YES;
    } else {
        [request qn_requestRemoveTask];
        return NO;
    }
}


+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    
    return request;
}


- (void)startLoading {
    
    [self loadingRequest:self.request];
}

- (void)stopLoading {

    [self.httpsClient stopLoading];
    self.httpsClient = nil;
}


- (void)loadingRequest:(NSURLRequest *)request{
    
    self.httpsClient = [QNCFHttpClient client:request];
    self.httpsClient.delegate = self;
    
    [NSURLProtocol setProperty:@(YES)
                        forKey:kQNRequestIdentifiers
                     inRequest:self.httpsClient.request];
    
    [self.httpsClient startLoading];
}

//MARK: -- delegate
- (void)didSendBodyData:(int64_t)bytesSent
         totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    
    id <NSURLSessionTaskDelegate> sessionDelegate = (id <NSURLSessionTaskDelegate>)self.request.qn_session.delegate;
    if ([sessionDelegate respondsToSelector:@selector(URLSession:
                                                      task:
                                                      didSendBodyData:
                                                      totalBytesSent:
                                                      totalBytesExpectedToSend:)]) {
        
        [sessionDelegate URLSession:self.request.qn_session
                               task:self.request.qn_task
                    didSendBodyData:bytesSent
                     totalBytesSent:totalBytesSent
           totalBytesExpectedToSend:totalBytesExpectedToSend];
    }
}

- (void)didFinish {
    
    [self.client URLProtocolDidFinishLoading:self];
    [self.request qn_requestRemoveTask];
}

- (void)didLoadData:(nonnull NSData *)data {
    
    [self.client URLProtocol:self didLoadData:data];
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {

    
    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }

    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);

    SecTrustResultType result = kSecTrustResultInvalid;
    
    OSStatus status = SecTrustEvaluate(serverTrust, &result);
    if (status != errSecSuccess) {
        return NO;
    }
    
    if (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed) {
        return YES;
    } else {
        return NO;
    }
}

- (void)onError:(nonnull NSError *)error {
    
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)onReceiveResponse:(nonnull NSURLResponse *)response {
    
    [self.client URLProtocol:self
          didReceiveResponse:response
          cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)redirectedToRequest:(nonnull NSURLRequest *)request redirectResponse:(nonnull NSURLResponse *)redirectResponse {
    
    if ([self.client respondsToSelector:@selector(URLProtocol:wasRedirectedToRequest:redirectResponse:)]) {
        [self.client URLProtocol:self wasRedirectedToRequest:request redirectResponse:redirectResponse];
        [self.client URLProtocolDidFinishLoading:self];
    } else {
        [self.httpsClient stopLoading];
        [self loadingRequest:request];
    }
}

@end


@implementation NSURLSessionConfiguration(QNURLProtocol)
+ (NSURLSessionConfiguration *)qn_sessionConfiguration{

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.protocolClasses = @[[QNURLProtocol class]];
    return config;
}
@end


