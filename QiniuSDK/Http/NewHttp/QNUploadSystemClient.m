//
//  QNUploadSystemClient.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/6.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadSystemClient.h"
#import "QNUserAgent.h"
#import "QNSystemTool.h"
#import "QNUploadInfoCollector.h"

#import "NSURLRequest+QNRequest.h"
#import "QNURLProtocol.h"

@interface QNUploadSystemClient()<NSURLSessionDelegate>

@property(nonatomic, strong)NSURLSessionDataTask *uploadTask;
@property(nonatomic, strong)NSMutableData *responseData;
@property(nonatomic,  copy)void(^progress)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
@property(nonatomic,  copy)void(^complete)(NSURLResponse * _Nullable, NSData * _Nullable, NSError * _Nullable);

@end
@implementation QNUploadSystemClient

- (void)request:(NSURLRequest *)request
connectionProxy:(NSDictionary *)connectionProxy
       progress:(void (^)(long long, long long))progress
       complete:(void (^)(NSURLResponse * _Nullable, NSData * _Nullable, NSError * _Nullable))complete{
    
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
    self.complete(task.response, self.responseData, error);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)) {
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {

    if (self.progress) {
        self.progress(totalBytesSent, totalBytesExpectedToSend);
    }
}

@end
