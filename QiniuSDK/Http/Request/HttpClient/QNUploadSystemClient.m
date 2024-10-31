//
//  QNUploadSystemClient.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/6.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadSystemClient.h"
#import "QNUserAgent.h"
#import "NSURLRequest+QNRequest.h"

@interface QNUploadSystemClient()<NSURLSessionTaskDelegate>

@property(nonatomic, strong)NSURLRequest *request;
@property(nonatomic, strong)QNUploadSingleRequestMetrics *requestMetrics;
@property(nonatomic, strong)NSURLSessionDataTask *uploadTask;
@property(nonatomic, strong)NSMutableData *responseData;
@property(nonatomic,  copy)void(^progress)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
@property(nonatomic,  copy)QNRequestClientCompleteHandler complete;

@end
@implementation QNUploadSystemClient

- (NSString *)clientId {
    return @"NSURLSession";
}

- (void)request:(NSURLRequest *)request
         server:(id <QNUploadServer>)server
connectionProxy:(NSDictionary *)connectionProxy
       progress:(void (^)(long long, long long))progress
       complete:(QNRequestClientCompleteHandler)complete {
    
    // 非 https 方可使用 IP
    if (!request.qn_isHttps && server && server.ip.length > 0 && server.host.length > 0) {
        NSString *urlString = request.URL.absoluteString;
        urlString = [urlString stringByReplacingOccurrencesOfString:server.host withString:server.ip];
        NSMutableURLRequest *requestNew = [request mutableCopy];
        requestNew.URL = [NSURL URLWithString:urlString];
        requestNew.qn_domain = server.host;
        self.request = [requestNew copy];
    } else {
        self.request = request;
    }

    self.requestMetrics = [QNUploadSingleRequestMetrics emptyMetrics];
    self.requestMetrics.remoteAddress = self.request.qn_isHttps ? nil : server.ip;
    self.requestMetrics.remotePort = self.request.qn_isHttps ? @443 : @80;
    [self.requestMetrics start];
    
    self.responseData = [NSMutableData data];
    self.progress = progress;
    self.complete = complete;
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    if (connectionProxy) {
        configuration.connectionProxyDictionary = connectionProxy;
    }
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *uploadTask = [session dataTaskWithRequest:self.request];
    [uploadTask resume];
    
    self.uploadTask = uploadTask;
}

- (void)cancel{
    [self.uploadTask cancel];
}

//MARK:-- NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    [self.requestMetrics end];
    self.requestMetrics.request = task.currentRequest;
    self.requestMetrics.response = task.response;
    self.requestMetrics.error = error;
    self.complete(task.response, self.requestMetrics,self.responseData, error);
    
    [session finishTasksAndInvalidate];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)) {
    NSURLSessionTaskTransactionMetrics *transactionMetrics = metrics.transactionMetrics.lastObject;
    
    self.requestMetrics.domainLookupStartDate = transactionMetrics.domainLookupStartDate;
    self.requestMetrics.domainLookupEndDate = transactionMetrics.domainLookupEndDate;
    self.requestMetrics.connectStartDate = transactionMetrics.connectStartDate;
    self.requestMetrics.secureConnectionStartDate = transactionMetrics.secureConnectionStartDate;
    self.requestMetrics.secureConnectionEndDate = transactionMetrics.secureConnectionEndDate;
    self.requestMetrics.connectEndDate = transactionMetrics.connectEndDate;
    
    self.requestMetrics.requestStartDate = transactionMetrics.requestStartDate;
    self.requestMetrics.requestEndDate = transactionMetrics.requestEndDate;
    self.requestMetrics.responseStartDate = transactionMetrics.responseStartDate;
    self.requestMetrics.responseEndDate = transactionMetrics.responseEndDate;
    
    if ([transactionMetrics.networkProtocolName isEqualToString:@"http/1.0"]) {
        self.requestMetrics.httpVersion = @"1.0";
    } else if ([transactionMetrics.networkProtocolName isEqualToString:@"http/1.1"]) {
        self.requestMetrics.httpVersion = @"1.1";
    } else if ([transactionMetrics.networkProtocolName isEqualToString:@"h2"]) {
        self.requestMetrics.httpVersion = @"2";
    } else if ([transactionMetrics.networkProtocolName isEqualToString:@"h3"]) {
        self.requestMetrics.httpVersion = @"3";
    } else {
        self.requestMetrics.httpVersion = transactionMetrics.networkProtocolName;
    }
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (@available(iOS 13.0, macOS 10.15, *)) {
        if (transactionMetrics.remoteAddress) {
            self.requestMetrics.remoteAddress = transactionMetrics.remoteAddress;
            self.requestMetrics.remotePort = transactionMetrics.remotePort;
        }
        if (transactionMetrics.countOfRequestHeaderBytesSent > 0) {
            self.requestMetrics.countOfRequestHeaderBytesSent = transactionMetrics.countOfRequestHeaderBytesSent;
        }
        if (transactionMetrics.countOfResponseHeaderBytesReceived > 0) {
            self.requestMetrics.countOfResponseHeaderBytesReceived = transactionMetrics.countOfResponseHeaderBytesReceived;
        }
        if (transactionMetrics.countOfResponseBodyBytesReceived > 0) {
            self.requestMetrics.countOfResponseBodyBytesReceived = transactionMetrics.countOfResponseBodyBytesReceived;
        }
    }
#endif
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    self.requestMetrics.countOfRequestBodyBytesSent = totalBytesSent;
    if (self.progress) {
        self.progress(totalBytesSent, totalBytesExpectedToSend);
    }
}

/*
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain {

    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
    
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);

    if (@available(iOS 13.0, macOS 10.14, *)) {
        CFErrorRef error = NULL;
        BOOL ret = SecTrustEvaluateWithError(serverTrust, &error);
        return ret && (error == nil);
    } else {
        SecTrustResultType result;
        SecTrustEvaluate(serverTrust, &result);
        return (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler {
    if (!challenge) {
        return;
    }
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;

    NSString* host = [[self.request allHTTPHeaderFields] objectForKey:@"host"];
    if (!host) {
        host = self.request.URL.host;
    }
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:host]) {
            disposition = NSURLSessionAuthChallengeUseCredential;
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }

    completionHandler(disposition,credential);
}
*/
@end
