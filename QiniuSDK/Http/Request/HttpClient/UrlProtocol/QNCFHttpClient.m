//
//  QNHttpClient.m
//  AppTest
//
//  Created by yangsen on 2020/4/7.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNCFHttpClient.h"
#import "NSURLRequest+QNRequest.h"

@interface QNCFHttpClient()<NSStreamDelegate>

@property(nonatomic, strong)NSMutableURLRequest *request;
@property(nonatomic, assign)BOOL isReadResponseHeader;
@property(nonatomic, assign)BOOL isInputStreamEvaluated;
@property(nonatomic, strong)NSInputStream *inputStream;
@property(nonatomic, strong)NSRunLoop *inputStreamRunLoop;

// 模拟上传进度
@property(nonatomic, strong)NSTimer *progressTimer; // 进度定时器
@property(nonatomic, assign)int64_t totalBytesSent; // 已上传大小
@property(nonatomic, assign)int64_t bytesSent; // 模拟每次上传大小
@property(nonatomic, assign)int64_t maxBytesSent; // 模拟上传最大值
@property(nonatomic, assign)int64_t totalBytesExpectedToSend; // 总大小

@end
@implementation QNCFHttpClient

+ (instancetype)client:(NSURLRequest *)request{
    if (!request) {
        return nil;
    }
    
    QNCFHttpClient *client = [[QNCFHttpClient alloc] init];
    [client setup:request];
    return client;
}

- (void)setup:(NSURLRequest *)request{
    
    @autoreleasepool {
        self.request = [request mutableCopy];
        NSInputStream *inputStream = [self createInputStream:self.request];
        
        NSString *host = [self.request qn_domain];
        if ([self.request qn_isHttps]) {
           [self setInputStreamSNI:inputStream sni:host];
        }
        
        [self setupProgress];
        
        self.inputStream = inputStream;
        
    }
}

- (void)startLoading{

    [self openInputStream];
    [self startProgress];
}

- (void)stopLoading{
    
    [self closeInputStream];
    [self endProgress:YES];
}

//MARK: -- request -> stream
- (NSInputStream *)createInputStream:(NSURLRequest *)urlRequest{
    
    CFStringRef urlString = (__bridge CFStringRef) [urlRequest.URL absoluteString];
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault,
                                         urlString,
                                         NULL);
    CFStringRef httpMethod = (__bridge CFStringRef) urlRequest.HTTPMethod;
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault,
                                                          httpMethod,
                                                          url,
                                                          kCFHTTPVersion1_1);
    CFRelease(url);
    
    
    NSDictionary *headFieldInfo = self.request.qn_allHTTPHeaderFields;
    for (NSString *headerField in headFieldInfo) {
        CFStringRef headerFieldP = (__bridge CFStringRef)headerField;
        CFStringRef headerFieldValueP = (__bridge CFStringRef)(headFieldInfo[headerField]);
        CFHTTPMessageSetHeaderFieldValue(request, headerFieldP, headerFieldValueP);
    }
    

    NSData *httpBody = [self.request qn_getHttpBody];
    if (httpBody) {
        CFDataRef bodyData = (__bridge CFDataRef) httpBody;
        CFHTTPMessageSetBody(request, bodyData);
    }
    
    CFReadStreamRef readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
    NSInputStream *inputStream = (__bridge_transfer NSInputStream *) readStream;
    
    CFRelease(request);
    
    return inputStream;
}

- (void)setInputStreamSNI:(NSInputStream *)inputStream sni:(NSString *)sni{
    if (!sni || sni.length == 0) {
        return;
    }
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings setObject:NSStreamSocketSecurityLevelNegotiatedSSL
                 forKey:NSStreamSocketSecurityLevelKey];
    [settings setObject:sni
                 forKey:(NSString *)kCFStreamSSLPeerName];
    [inputStream setProperty:settings forKey:(NSString *)CFBridgingRelease(kCFStreamPropertySSLSettings)];
}


//MARK: -- stream action
- (void)openInputStream{
    if (!self.inputStreamRunLoop) {
        self.inputStreamRunLoop = [NSRunLoop currentRunLoop];
    }
    [self.inputStream scheduleInRunLoop:self.inputStreamRunLoop
                                forMode:NSRunLoopCommonModes];
    
    self.inputStream.delegate = self;
    [self.inputStream open];
}

- (void)closeInputStream {
    [self.inputStream removeFromRunLoop:self.inputStreamRunLoop forMode:NSRunLoopCommonModes];
    [self.inputStream setDelegate:nil];
    [self.inputStream close];
    self.inputStream = nil;
}

- (BOOL)shouldEvaluateInputStreamServerTrust{
    if (![self.request qn_isHttps] || self.isInputStreamEvaluated) {
        return NO;
    } else {
        return YES;
    }
}

- (void)evaluateInputStreamServerTrust{
    if (self.isInputStreamEvaluated) {
        return;
    }
    
    SecTrustRef trust = (__bridge SecTrustRef) [self.inputStream propertyForKey:(__bridge NSString *) kCFStreamPropertySSLPeerTrust];
    NSString *host = [self.request allHTTPHeaderFields][@"host"];
    if ([self delegate_evaluateServerTrust:trust forDomain:host]) {
        self.isInputStreamEvaluated = YES;
    } else {
        [self delegate_onError:[NSError errorWithDomain:@"CFNetwork SSLHandshake failed"
                                                   code:-9807
                                               userInfo:nil]];
    }
}

- (void)inputStreamGetAndNotifyHttpResponse{

    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef httpMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    
    CFDictionaryRef headerFields = CFHTTPMessageCopyAllHeaderFields(httpMessage);
    NSDictionary *headInfo = (__bridge_transfer NSDictionary *)headerFields;
    
    CFStringRef httpVersion = CFHTTPMessageCopyVersion(httpMessage);
    NSString *httpVersionInfo = (__bridge_transfer NSString *)httpVersion;
    
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(httpMessage);
    
    if (![self isHttpRedirectStatusCode:statusCode]) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:statusCode HTTPVersion:httpVersionInfo headerFields:headInfo];
        [self delegate_onReceiveResponse:response];
    }
    
    CFRelease(httpMessage);
}

- (void)inputStreamGetAndNotifyHttpData{
    
    UInt8 buffer[16 * 1024];
    UInt8 *buf = NULL;
    NSUInteger length = 0;
    
    if (![self.inputStream getBuffer:&buf length:&length]) {
        NSInteger amount = [self.inputStream read:buffer maxLength:sizeof(buffer)];
        buf = buffer;
        length = amount;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:buf length:length];
    [self delegate_didLoadData:data];
}

- (void)inputStreamDidLoadHttpResponse{
    
    [self delegate_didFinish];
}

- (BOOL)isInputStreamHttpResponseHeaderComplete{
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    BOOL isComplete = CFHTTPMessageIsHeaderComplete(responseMessage);
    CFRelease(responseMessage);
    return isComplete;
}

- (BOOL)shouldInputStreamRedirect{
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(responseMessage);
    CFRelease(responseMessage);
    return [self isHttpRedirectStatusCode:statusCode];
}

- (BOOL)isHttpRedirectStatusCode:(NSInteger)code{
    if (code >= 300 && code < 400) {
        return YES;
    } else {
        return NO;
    }
}

- (void)inputStreamRedirect{
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    
    CFDictionaryRef headerFields = CFHTTPMessageCopyAllHeaderFields(responseMessage);
    NSDictionary *headInfo = (__bridge_transfer NSDictionary *)headerFields;
    
    NSString *urlString = headInfo[@"Location"];
    if (!urlString) {
        urlString = headInfo[@"location"];
    }
    if (!urlString) {
        return;
    }
    
    CFStringRef httpVersion = CFHTTPMessageCopyVersion(responseMessage);
    NSString *httpVersionString = (__bridge_transfer NSString *)httpVersion;
    
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(responseMessage);
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                          statusCode:statusCode
                                                         HTTPVersion:httpVersionString
                                                        headerFields:headInfo];
    
    [self delegate_redirectedToRequest:request redirectResponse:response];
    
    CFRelease(responseMessage);
}

//MARK: -- NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    @autoreleasepool {
        switch (eventCode) {
            case NSStreamEventHasBytesAvailable:{
                
                if (![self isInputStreamHttpResponseHeaderComplete]) {
                    break;
                }
                
                if ([self shouldEvaluateInputStreamServerTrust]) {
                    [self evaluateInputStreamServerTrust];
                }
                
                if (self.isReadResponseHeader == NO) {
                    self.isReadResponseHeader = YES;
                    [self inputStreamGetAndNotifyHttpResponse];
                }
                
                [self inputStreamGetAndNotifyHttpData];
            }
                break;
            case NSStreamEventHasSpaceAvailable:
                break;
            case NSStreamEventErrorOccurred:{
                [self endProgress: YES];
                [self closeInputStream];
                [self delegate_onError:[self.inputStream streamError]];
            }
                break;
            case NSStreamEventEndEncountered:{
                if ([self shouldInputStreamRedirect]) {
                    [self inputStreamRedirect];
                } else {
                    [self endProgress: NO];
                    [self inputStreamDidLoadHttpResponse];
                }
            }
                break;
            default:
                break;
        }
    }
}

//MARK: -- progress and timer action
- (void)setupProgress{
    self.bytesSent = 256 * 1024;
    self.totalBytesExpectedToSend = [self.request.qn_getHttpBody length];
    self.maxBytesSent = self.totalBytesExpectedToSend * 0.5;
}

- (void)startProgress{
    [self createTimer];
}

- (void)endProgress:(BOOL)hasError{
    
    [self invalidateTimer];
    
    if (!hasError) {
        [self delegate_didSendBodyData:self.totalBytesExpectedToSend - self.totalBytesSent
                        totalBytesSent:self.totalBytesExpectedToSend
              totalBytesExpectedToSend:self.totalBytesExpectedToSend];
    }
}

- (void)createTimer{
    
    if (_progressTimer) {
        [self invalidateTimer];
    }
    
    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.5
                                             target:weakSelf
                                           selector:@selector(timerAction)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer
                                 forMode:NSDefaultRunLoopMode];
    
    [self timerAction];
    _progressTimer = timer;
}

- (void)invalidateTimer{
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)timerAction{

    self.totalBytesSent += self.bytesSent;
    if (self.totalBytesSent < self.maxBytesSent) {
        [self delegate_didSendBodyData:self.bytesSent
                        totalBytesSent:self.totalBytesSent
              totalBytesExpectedToSend:self.totalBytesExpectedToSend];
    }
}


//MARK: -- delegate action
- (void)delegate_redirectedToRequest:(NSURLRequest *)request
                    redirectResponse:(NSURLResponse *)redirectResponse{
    if ([self.delegate respondsToSelector:@selector(redirectedToRequest:redirectResponse:)]) {
        [self.delegate redirectedToRequest:request redirectResponse:redirectResponse];
    }
}

- (BOOL)delegate_evaluateServerTrust:(SecTrustRef)serverTrust
                           forDomain:(NSString *)domain{
    if ([self.delegate respondsToSelector:@selector(evaluateServerTrust:forDomain:)]) {
        return [self.delegate evaluateServerTrust:serverTrust forDomain:domain];
    } else {
        return NO;
    }
}

- (void)delegate_onError:(NSError *)error{
    if ([self.delegate respondsToSelector:@selector(onError:)]) {
        [self.delegate onError:error];
    }
}

- (void)delegate_didSendBodyData:(int64_t)bytesSent
                  totalBytesSent:(int64_t)totalBytesSent
        totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    if ([self.delegate respondsToSelector:@selector(didSendBodyData:
                                                    totalBytesSent:
                                                    totalBytesExpectedToSend:)]) {
        [self.delegate didSendBodyData:bytesSent
                        totalBytesSent:totalBytesSent
              totalBytesExpectedToSend:totalBytesExpectedToSend];
    }
}
- (void)delegate_onReceiveResponse:(NSURLResponse *)response{
    if ([self.delegate respondsToSelector:@selector(onReceiveResponse:)]) {
        [self.delegate onReceiveResponse:response];
    }
}

- (void)delegate_didLoadData:(NSData *)data{
    if ([self.delegate respondsToSelector:@selector(didLoadData:)]) {
        [self.delegate didLoadData:data];
    }
}

- (void)delegate_didFinish{
    if ([self.delegate respondsToSelector:@selector(didFinish)]) {
        [self.delegate didFinish];
    }
}

@end
