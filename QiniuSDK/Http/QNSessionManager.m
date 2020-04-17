//
//  QNHttpManager.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import "QNConfiguration.h"
#import "QNResponseInfo.h"
#import "QNSessionManager.h"
#import "QNUserAgent.h"
#import "QNSystemTool.h"
#import "QNUploadInfoReporter.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)



@interface QNSessionStatistics ()

@property (nonatomic, copy, readwrite) NSString *remoteIp;
@property (nonatomic, assign, readwrite) uint16_t port;
@property (nonatomic, assign, readwrite) uint64_t totalElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t dnsElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t connectElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t tlsConnectElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t requestElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t waitElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t responseElapsedTime;
@property (nonatomic, assign, readwrite) uint64_t bytesSent;
@property (nonatomic, assign, readwrite) uint64_t bytesTotal;
@property (nonatomic, assign, readwrite) BOOL isProxyConnection;
@property (nonatomic, copy, readwrite) NSString *errorType;
@property (nonatomic, copy, readwrite) NSString *errorDescription;
@property (nonatomic, assign, readwrite) int64_t pid;
@property (nonatomic, assign, readwrite) int64_t tid;
@property (nonatomic, copy, readwrite) NSString *networkType;
@property (nonatomic, assign, readwrite) int64_t signalStrength;

@end

@implementation QNSessionStatistics
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isProxyConnection = NO;
    }
    return self;
}
@end

typedef void (^QNSessionComplete)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, QNSessionStatistics *sessionStatistics);
@interface QNSessionDelegateHandler : NSObject <NSURLSessionDataDelegate>

@property (nonatomic, copy) QNInternalProgressBlock progressBlock;
@property (nonatomic, copy) QNCancelBlock cancelBlock;
@property (nonatomic, copy) QNSessionComplete completeBlock;
@property (nonatomic, strong) QNSessionStatistics *sessionStatistics;
@property (nonatomic, strong) NSData *responseData;

@end

@implementation QNSessionDelegateHandler
- (instancetype)init
{
    self = [super init];
    if (self) {
        _sessionStatistics = [[QNSessionStatistics alloc] init];
    }
    return self;
}

- (uint64_t)getTimeintervalWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    
    if (!startDate || !endDate) return 0;
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    return interval * 1000;
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    _responseData = data;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
        
    // pid & tid
    _sessionStatistics.pid = [QNSystemTool getCurrentProcessID];
    _sessionStatistics.tid = [QNSystemTool getCurrentThreadID];
    
    // networkType & signalStrength
    _sessionStatistics.networkType = [QNSystemTool getCurrentNetworkType];
    _sessionStatistics.signalStrength = [QNSystemTool getCurrentNetworkSignalStrength];
    
    // errorType & errorDescription
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    if (response) {
        if (response.statusCode != 200) {
            if (response.statusCode / 100 == 4) {
                _sessionStatistics.errorType = bad_request;
            }  else {
                _sessionStatistics.errorType = response_error;
            }
        }
    } else {
        if (_sessionStatistics.isProxyConnection) {
            _sessionStatistics.errorType = proxy_error;
        } else {
            if (error) {
                if (error.code == -1) {
                    _sessionStatistics.errorType = network_error;
                } else if (error.code == -1001) {
                    _sessionStatistics.errorType = timeout;
                } else if (error.code == -1003 || error.code == -1006) {
                    _sessionStatistics.errorType = unknown_host;
                } else if (error.code == -1004) {
                    _sessionStatistics.errorType = cannot_connect_to_host;
                } else if (error.code == -1005 || error.code == -1009 || error.code == -1011) {
                    _sessionStatistics.errorType = transmission_error;
                } else if (error.code > -2001 || error.code < -1199) {
                    _sessionStatistics.errorType = ssl_error;
                } else if (error.code == -1007 || error.code == -1010) {
                    _sessionStatistics.errorType = malicious_response;
                } else if (error.code == -1015 || error.code == -1016 || error.code == -1017) {
                    _sessionStatistics.errorType = parse_error;
                } else if (error.code == -999) {
                    _sessionStatistics.errorType = user_canceled;
                } else {
                    _sessionStatistics.errorType = unknown_error;
                }
            } else {
                _sessionStatistics.errorType = unknown_error;
            }
        }
    }
    _sessionStatistics.errorDescription = error ? error.localizedDescription : nil;
    self.completeBlock(_responseData, task.response, error, _sessionStatistics);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)) {
    
    if (metrics.transactionMetrics.count > 0) {
        NSURLSessionTaskTransactionMetrics *transactionMetrics = metrics.transactionMetrics[0];
        
        // status_code
        _sessionStatistics.bytesSent = task.countOfBytesSent;
        _sessionStatistics.bytesTotal = task.countOfBytesExpectedToSend;
        
        // remote_ip & port
        if (@available(iOS 13.0, *)) {
            _sessionStatistics.remoteIp = transactionMetrics.remoteAddress;
            _sessionStatistics.port = [transactionMetrics.remotePort unsignedShortValue];
        } else {
            NSString *remoteIpAddressAndPort = [transactionMetrics valueForKey:@"__remoteAddressAndPort"];
            NSRange indexRange = [remoteIpAddressAndPort rangeOfString:@":"];
            _sessionStatistics.remoteIp = [remoteIpAddressAndPort substringToIndex:indexRange.location];
            _sessionStatistics.port = [[remoteIpAddressAndPort substringFromIndex:indexRange.location + 1] intValue ];
        }
        
        // time
        _sessionStatistics.totalElapsedTime = metrics.taskInterval.duration * 1000;
        _sessionStatistics.dnsElapsedTime = [self getTimeintervalWithStartDate:transactionMetrics.domainLookupStartDate endDate:transactionMetrics.domainLookupEndDate];
        _sessionStatistics.connectElapsedTime =
        [self getTimeintervalWithStartDate:transactionMetrics.connectStartDate endDate:transactionMetrics.connectEndDate];
        _sessionStatistics.tlsConnectElapsedTime = [self getTimeintervalWithStartDate:transactionMetrics.secureConnectionStartDate endDate:transactionMetrics.secureConnectionEndDate];
        _sessionStatistics.requestElapsedTime = [self getTimeintervalWithStartDate:transactionMetrics.requestStartDate endDate:transactionMetrics.requestEndDate];
        _sessionStatistics.waitElapsedTime = [self getTimeintervalWithStartDate:transactionMetrics.requestEndDate endDate:transactionMetrics.responseStartDate];
        _sessionStatistics.responseElapsedTime = [self getTimeintervalWithStartDate:transactionMetrics.responseStartDate endDate:transactionMetrics.responseEndDate];
        
        // proxy
        _sessionStatistics.isProxyConnection = transactionMetrics.isProxyConnection;
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {

    if (_progressBlock) {
        _progressBlock(totalBytesSent, totalBytesExpectedToSend);
    }
    if (_cancelBlock && _cancelBlock()) {
        [task cancel];
    }
}

@end

@interface QNSessionManager ()
@property UInt32 timeout;
@property (nonatomic, strong) QNUrlConvert converter;
@property (nonatomic, strong) NSDictionary *proxyDict;
@property (nonatomic, strong) NSOperationQueue *delegateQueue;
@property (nonatomic, strong) NSMutableArray *sessionArray;
@end

@implementation QNSessionManager

- (instancetype)initWithProxy:(NSDictionary *)proxyDict
                      timeout:(UInt32)timeout
                 urlConverter:(QNUrlConvert)converter {
    if (self = [super init]) {
        _delegateQueue = [[NSOperationQueue alloc] init];
        _timeout = timeout;
        _converter = converter;
        _sessionArray = [NSMutableArray array];
    }
    return self;
}

- (instancetype)init {
    return [self initWithProxy:nil timeout:60 urlConverter:nil];
}

+ (QNResponseInfo *)buildResponseInfo:(NSHTTPURLResponse *)response
                            withError:(NSError *)error
                         withDuration:(double)duration
                         withResponse:(NSData *)body
                             withHost:(NSString *)host
                               withIp:(NSString *)ip {
    QNResponseInfo *info;

    if (response) {
        int status = (int)[response statusCode];
        NSDictionary *headers = [response allHeaderFields];
        NSString *reqId = headers[@"X-Reqid"];
        NSString *xlog = headers[@"X-Log"];
        NSString *xvia = headers[@"X-Via"];
        if (xvia == nil) {
            xvia = headers[@"X-Px"];
        }
        if (xvia == nil) {
            xvia = headers[@"Fw-Via"];
        }
        info = [[QNResponseInfo alloc] init:status withReqId:reqId withXLog:xlog withXVia:xvia withHost:host withIp:ip withDuration:duration withBody:body];
    } else {
        info = [QNResponseInfo responseInfoWithNetError:error host:host duration:duration];
    }
    return info;
}

- (void)sendRequest:(NSMutableURLRequest *)request
     withIdentifier:(NSString *)identifier
  withCompleteBlock:(QNCompleteBlock)completeBlock
  withProgressBlock:(QNInternalProgressBlock)progressBlock
    withCancelBlock:(QNCancelBlock)cancelBlock
         withAccess:(NSString *)access {
    
    NSDate *startTime = [NSDate date];
    NSString *domain = request.URL.host;
    NSString *u = request.URL.absoluteString;
    NSURL *url = request.URL;
    if (_converter != nil) {
        url = [[NSURL alloc] initWithString:_converter(u)];
        request.URL = url;
        domain = url.host;
    }
    [request setTimeoutInterval:_timeout];
    [request setValue:[[QNUserAgent sharedInstance] getUserAgent:access] forHTTPHeaderField:@"User-Agent"];
    [request setValue:nil forHTTPHeaderField:@"Accept-Language"];
    
    QNSessionDelegateHandler *delegate = [[QNSessionDelegateHandler alloc] init];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.connectionProxyDictionary = _proxyDict ? _proxyDict : nil;
    __block NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:_delegateQueue];
    [_sessionArray addObject:@{@"identifier":identifier,@"session":session}];

    delegate.cancelBlock = cancelBlock;
    delegate.progressBlock = progressBlock ? progressBlock : ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
    };
    delegate.completeBlock = ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, QNSessionStatistics *sessionStatistics) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        double duration = [[NSDate date] timeIntervalSinceDate:startTime];
        QNResponseInfo *info;
        NSDictionary *resp = nil;
        
        if (error == nil) {
            info = [QNSessionManager buildResponseInfo:httpResponse withError:nil withDuration:duration withResponse:data withHost:domain withIp:nil];
            if (info.isOK) {
                NSError *tmp;
                resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&tmp];
            }
        } else {
            info = [QNSessionManager buildResponseInfo:httpResponse withError:error withDuration:duration withResponse:data withHost:domain withIp:nil];
        }
        [self finishSession:session];
        completeBlock(info, resp, sessionStatistics);
    };
    
    NSURLSessionDataTask *uploadTask = [session dataTaskWithRequest:request];
    [uploadTask resume];
}

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
       withIdentifier:(NSString *)identifier
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock
           withAccess:(NSString *)access {
    NSURL *URL = [[NSURL alloc] initWithString:url];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    request.HTTPMethod = @"POST";
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    request.allHTTPHeaderFields = @{
        @"Content-Type" : [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
    };
    NSMutableData *postData = [[NSMutableData alloc] init];
    for (NSString *paramsKey in params) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n", boundary, paramsKey];
        [postData appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

        id value = [params objectForKey:paramsKey];
        if ([value isKindOfClass:[NSString class]]) {
            [postData appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSData class]]) {
            [postData appendData:value];
        }
        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\nContent-Type:%@\r\n\r\n", boundary, @"file", key, mime];
    [postData appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:data];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)postData.length] forHTTPHeaderField:@"Content-Length"];

    [self sendRequest:request withIdentifier:identifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:cancelBlock
               withAccess:access];
}

- (void)post:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
          withHeaders:(NSDictionary *)headers
withIdentifier:(NSString *)identifier
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock
           withAccess:(NSString *)access {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:url]];
    if (headers) {
        [request setAllHTTPHeaderFields:headers];
    }
    [request setHTTPMethod:@"POST"];
    if (params) {
        [request setValuesForKeysWithDictionary:params];
    }
    [request setHTTPBody:data];
    QNAsyncRun(^{
        [self sendRequest:request
           withIdentifier:identifier
            withCompleteBlock:completeBlock
            withProgressBlock:progressBlock
              withCancelBlock:cancelBlock
                   withAccess:access];
    });
}

- (void)get:(NSString *)url
          withHeaders:(NSDictionary *)headers
    withCompleteBlock:(QNCompleteBlock)completeBlock {
    QNAsyncRun(^{
        NSURL *URL = [NSURL URLWithString:url];
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];

        QNSessionDelegateHandler *delegate = [[QNSessionDelegateHandler alloc] init];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        __block NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:self.delegateQueue];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
        delegate.cancelBlock = nil;
        delegate.progressBlock = nil;
        delegate.completeBlock = ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, QNSessionStatistics *sessionStatistics) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSData *s = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *resp = nil;
            QNResponseInfo *info;
            if (error == nil) {
                info = [QNSessionManager buildResponseInfo:httpResponse withError:nil withDuration:0 withResponse:s withHost:@"" withIp:@""];
                if (info.isOK) {
                    NSError *jsonError;
                    id unMarshel = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
                    if (jsonError) {
                        info = [QNSessionManager buildResponseInfo:httpResponse withError:jsonError withDuration:0 withResponse:s withHost:@"" withIp:@""];
                    } else if ([unMarshel isKindOfClass:[NSDictionary class]]) {
                        resp = unMarshel;
                    }
                }
            } else {
                info = [QNSessionManager buildResponseInfo:httpResponse withError:error withDuration:0 withResponse:s withHost:@"" withIp:@""];
            }
            completeBlock(info, resp, sessionStatistics);
        };
        [dataTask resume];
    });
}

- (void)finishSession:(NSURLSession *)session {
    for (int i = 0; i < _sessionArray.count; i++) {
        NSDictionary *sessionInfo = _sessionArray[i];
        if (sessionInfo[@"session"] == session) {
            [session finishTasksAndInvalidate];
            [_sessionArray removeObject:sessionInfo];
            break;
        }
    }
}

- (void)invalidateSessionWithIdentifier:(NSString *)identifier {
    
    for (int i = 0; i < _sessionArray.count; i++) {
        NSDictionary *sessionInfo = _sessionArray[i];
        if ([sessionInfo[@"identifier"] isEqualToString:identifier]) {
            NSURLSession *session = sessionInfo[@"session"];
            [session invalidateAndCancel];
            [_sessionArray removeObject:sessionInfo];
        }
    }
}

@end

#endif
