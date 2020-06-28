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
#import "QNURLProtocol.h"

@interface QNUploadSystemClient()<NSURLSessionDelegate>

@property(nonatomic, strong)QNUploadSingleRequestMetrics *requestMetrics;
@property(nonatomic, strong)NSURLSessionDataTask *uploadTask;
@property(nonatomic, strong)NSMutableData *responseData;
@property(nonatomic,  copy)void(^progress)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
@property(nonatomic,  copy)QNRequestClientCompleteHandler complete;

@end
@implementation QNUploadSystemClient

- (void)request:(NSURLRequest *)request
connectionProxy:(NSDictionary *)connectionProxy
       progress:(void (^)(long long, long long))progress
       complete:(QNRequestClientCompleteHandler)complete {
    
    self.requestMetrics = [QNUploadSingleRequestMetrics emptyMetrics];
    self.requestMetrics.remoteAddress = request.qn_ip;
    self.requestMetrics.startDate = [NSDate date];
    
    self.responseData = [NSMutableData data];
    self.progress = progress;
    self.complete = complete;
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration qn_sessionConfiguration];
    if (connectionProxy) {
        configuration.connectionProxyDictionary = connectionProxy;
    }
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *uploadTask = [session dataTaskWithRequest:request];
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
    
    self.requestMetrics.endDate = [NSDate date];
    self.requestMetrics.request = task.currentRequest;
    self.requestMetrics.response = task.response;
    self.requestMetrics.countOfResponseBodyBytesReceived = task.response.expectedContentLength;
    self.requestMetrics.countOfRequestHeaderBytesSent = [NSString stringWithFormat:@"%@", task.currentRequest.allHTTPHeaderFields].length;
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
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (@available(iOS 13.0, *)) {
        self.requestMetrics.localAddress = transactionMetrics.localAddress;
        self.requestMetrics.localPort = transactionMetrics.localPort;
        self.requestMetrics.remoteAddress = transactionMetrics.remoteAddress;
        self.requestMetrics.remotePort = transactionMetrics.remotePort;
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

@end
