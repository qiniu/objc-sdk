//
//  QNHttpClient.m
//  AppTest
//
//  Created by yangsen on 2020/4/7.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNErrorCode.h"
#import "QNDefine.h"
#import "QNCFHttpClient.h"
#import "NSURLRequest+QNRequest.h"
#import <sys/errno.h>

@interface QNCFHttpClient()<NSStreamDelegate>

@property(nonatomic, strong)NSMutableURLRequest *request;
@property(nonatomic, assign)BOOL isReadResponseHeader;
@property(nonatomic, assign)BOOL isInputStreamEvaluated;
@property(nonatomic, strong)NSInputStream *inputStream;
@property(nonatomic, strong)NSRunLoop *inputStreamRunLoop;

// 上传进度
@property(nonatomic, strong)NSTimer *progressTimer; // 进度定时器
@property(nonatomic, assign)int64_t totalBytesSent; // 已上传大小
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
                                                   code:NSURLErrorSecureConnectionFailed
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
                [self delegate_onError:[self translateCFNetworkErrorIntoUrlError:[self.inputStream streamError]]];
                [self closeInputStream];
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
    self.totalBytesExpectedToSend = [self.request.qn_getHttpBody length];
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
    
    kQNWeakSelf;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.5
                                             target:weak_self
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
    long long totalBytesSent = [(NSNumber *)CFBridgingRelease(CFReadStreamCopyProperty((CFReadStreamRef)[self inputStream], kCFStreamPropertyHTTPRequestBytesWrittenCount)) longLongValue];
    long long bytesSent = totalBytesSent - self.totalBytesSent;
    self.totalBytesSent = totalBytesSent;
    if (bytesSent > 0 && self.totalBytesSent <= self.totalBytesSent) {
        [self delegate_didSendBodyData:bytesSent
                        totalBytesSent:self.totalBytesSent
              totalBytesExpectedToSend:self.totalBytesExpectedToSend];
    }
}

- (NSError *)translateCFNetworkErrorIntoUrlError:(NSError *)cfError{
    if (cfError == nil) {
        return nil;
    }
    
    NSInteger errorCode = kQNNetworkError;
    NSString *errorInfo = [NSString stringWithFormat:@"cf client:[%ld] %@", (long)errorCode, cfError.localizedDescription];
    switch (cfError.code) {
        case ENOENT: /* No such file or directory */
            errorCode = NSFileNoSuchFileError;
            break;
        case EIO: /* Input/output error */
            errorCode = kQNLocalIOError;
            break;
        case E2BIG: /* Argument list too long */
            break;
        case ENOEXEC: /* Exec format error */
            errorCode = kQNLocalIOError;
            break;
        case EBADF: /* Bad file descriptor */
            errorCode = kQNLocalIOError;
            break;
        case ECHILD: /* No child processes */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EDEADLK: /* Resource deadlock avoided */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENOMEM: /* Cannot allocate memory */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EACCES: /* Permission denied */
            errorCode = NSURLErrorNoPermissionsToReadFile;
            break;
        case EFAULT: /* Bad address */
            errorCode = NSURLErrorBadURL;
            break;
        case EBUSY: /* Device / Resource busy */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EEXIST: /* File exists */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENODEV: /* Operation not supported by device */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EISDIR: /* Is a directory */
            errorCode = NSURLErrorFileIsDirectory;
            break;
        case ENOTDIR: /* Not a directory */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EINVAL: /* Invalid argument */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENFILE: /* Too many open files in system */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EMFILE: /* Too many open files */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EFBIG: /* File too large */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENOSPC: /* No space left on device */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ESPIPE: /* Illegal seek */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EMLINK: /* Too many links */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EPIPE: /* Broken pipe */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EDOM: /* Numerical argument out of domain */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ERANGE: /* Result too large */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EAGAIN: /* Resource temporarily unavailable */
            break;
        case ENOTSOCK: /* Socket operation on non-socket */
            break;
        case EDESTADDRREQ: /* Destination address required */
            errorCode = NSURLErrorBadURL;
            break;
        case EMSGSIZE: /* Message too long */
            break;
        case EPROTOTYPE: /* Protocol wrong type for socket */
            break;
        case ENOPROTOOPT: /* Protocol not available */
            break;
        case EPROTONOSUPPORT: /* Protocol not supported */
            break;
        case ENOTSUP: /* Operation not supported */
            break;
        case EPFNOSUPPORT: /* Protocol family not supported */
            break;
        case EAFNOSUPPORT: /* Address family not supported by protocol family */
            break;
        case EADDRINUSE: /* Address already in use */
            break;
        case EADDRNOTAVAIL: /* Can't assign requested address */
            break;
        case ENETDOWN: /* Network is down */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case ENETUNREACH: /* Network is unreachable */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ENETRESET: /* Network dropped connection on reset */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ECONNABORTED: /* Software caused connection abort */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ECONNRESET: /* Connection reset by peer */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ENOBUFS: /* No buffer space available */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EISCONN: /* Socket is already connected */
            break;
        case ENOTCONN: /* Socket is not connected */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case ESHUTDOWN: /* Can't send after socket shutdown */
            break;
        case ETOOMANYREFS: /* Too many references: can't splice */
            break;
        case ETIMEDOUT: /* Operation timed out */
            errorCode = NSURLErrorTimedOut;
            break;
        case ECONNREFUSED: /* Connection refused */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case ELOOP: /* Too many levels of symbolic links */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENAMETOOLONG: /* File name too long */
            break;
        case EHOSTDOWN: /* Host is down */
            break;
        case EHOSTUNREACH: /* No route to host */
            break;
        case ENOTEMPTY: /* Directory not empty */
            break;
        case EPROCLIM: /* Too many processes */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EUSERS: /* Too many users */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EDQUOT: /* Disc quota exceeded */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ESTALE: /* Stale NFS file handle */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EREMOTE: /* Too many levels of remote in path */
            break;
        case EBADRPC: /* RPC struct is bad */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ERPCMISMATCH: /* RPC version wrong */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EPROGUNAVAIL: /* RPC prog. not avail */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EPROGMISMATCH: /* Program version wrong */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EPROCUNAVAIL: /* Bad procedure for program */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENOLCK: /* No locks available */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ENOSYS: /* Function not implemented */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EFTYPE: /* Inappropriate file type or format */
            break;
        case EAUTH: /* Authentication error */
            break;
        case ENEEDAUTH: /* Need authenticator */
            break;
        case EPWROFF: /* Device power is off */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EDEVERR: /* Device error, e.g. paper out */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EOVERFLOW: /* Value too large to be stored in data type */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EBADEXEC: /* Bad executable */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EBADARCH: /* Bad CPU type in executable */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ESHLIBVERS: /* Shared library version mismatch */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EBADMACHO: /* Malformed Macho file */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case ECANCELED: /* Operation canceled */
            errorCode = NSURLErrorCancelled;
            break;
        case EIDRM: /* Identifier removed */
            break;
        case ENOMSG: /* No message of desired type */
            break;
        case EILSEQ: /* Illegal byte sequence */
            break;
        case ENOATTR: /* Attribute not found */
            break;
        case EBADMSG: /* Bad message */
            break;
        case EMULTIHOP: /* Reserved */
            break;
        case ENODATA: /* No message available on STREAM */
            break;
        case ENOLINK: /* Reserved */
            break;
        case ENOSR: /* No STREAM resources */
            break;
        case ENOSTR: /* Not a STREAM */
            break;
        case EPROTO: /* Protocol error */
            break;
        case ETIME: /* STREAM ioctl timeout */
            errorCode = NSURLErrorTimedOut;
            break;
        case EOPNOTSUPP: /* Operation not supported on socket */
            break;
        case ENOPOLICY: /* No such policy registered */
            break;
        case ENOTRECOVERABLE: /* State not recoverable */
            break;
        case EOWNERDEAD: /* Previous owner died */
            errorCode = kQNUnexpectedSysCallError;
            break;
        case EQFULL: /* Interface output queue is full */
            break;

        default:
            break;
    }
    
    return [NSError errorWithDomain:NSURLErrorDomain code:errorCode userInfo:@{@"UserInfo" : errorInfo ?: @""}];
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
