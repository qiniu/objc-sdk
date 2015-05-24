//
//  QNHttpManager.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>

#import "QNConfiguration.h"
#import "QNHttpManager.h"
#import "QNUserAgent.h"
#import "QNResponseInfo.h"
#import "QNDns.h"

@interface QNHttpManager ()
@property (nonatomic) AFHTTPRequestOperationManager *httpManager;
@property UInt32 timeout;
@property (nonatomic, strong) QNUrlConvert converter;
@property (nonatomic) NSString *backupIp;
@end

@implementation QNHttpManager

- (instancetype)initWithTimeout:(UInt32)timeout
                   urlConverter:(QNUrlConvert)converter
                       backupIp:(NSString *)ip {
	if (self = [super init]) {
		_httpManager = [[AFHTTPRequestOperationManager alloc] init];
		_httpManager.responseSerializer = [AFJSONResponseSerializer serializer];
		_timeout = timeout;
		_converter = converter;
	}

	return self;
}

- (instancetype)init {
	return [self initWithTimeout:60 urlConverter:nil backupIp:nil];
}

+ (QNResponseInfo *)buildResponseInfo:(AFHTTPRequestOperation *)operation
                            withError:(NSError *)error
                         withDuration:(double)duration
                         withResponse:(id)responseObject
                               withIp:(NSString *)ip{
	QNResponseInfo *info;
	NSString *host = operation.request.URL.host;

	if (operation.response) {
		int status =  (int)[operation.response statusCode];
		NSDictionary *headers = [operation.response allHeaderFields];
		NSString *reqId = headers[@"X-Reqid"];
		NSString *xlog = headers[@"X-Log"];
		NSString *xvia = headers[@"X-Via"];
		if (xvia == nil) {
			xvia = headers[@"X-Px"];
		}
        info = [[QNResponseInfo alloc] init:status withReqId:reqId withXLog:xlog withXVia:xvia withHost:host withIp:ip withDuration:duration withBody:responseObject];
	}
	else {
		info = [QNResponseInfo responseInfoWithNetError:error host:host duration:duration];
	}
	return info;
}

- (void)  sendRequest:(NSMutableURLRequest *)request
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock {
    
    NSString *u = request.URL.absoluteString;
    NSURL *url = request.URL;
    __block NSString *ip = nil;
    if (_converter != nil) {
        url = [[NSURL alloc] initWithString:_converter(u)];
    }else {
        if (_backupIp != nil && ![_backupIp isEqualToString:@""]) {
            NSString *host = url.host;
            ip = [QNDns getAddress:host];
            if ([ip isEqualToString:@""]) {
                ip = _backupIp;
            }
            NSString *path = url.path;
            if (path == nil || [@"" isEqualToString:path]) {
                path = @"/";
            }
            url = [[NSURL alloc] initWithScheme:url.scheme host:ip path: path];
            [request setValue:host forHTTPHeaderField:@"Host"];
        }
    }
    request.URL = url;

	__block NSDate *startTime = [NSDate date];
	AFHTTPRequestOperation *operation = [_httpManager
	                                     HTTPRequestOperationWithRequest:request
	                                                             success: ^(AFHTTPRequestOperation *operation, id responseObject) {
	    double duration = [[NSDate date] timeIntervalSinceDate:startTime];
	    QNResponseInfo *info = [QNHttpManager buildResponseInfo:operation withError:nil withDuration:duration withResponse:operation.responseData  withIp:ip];
	    NSDictionary *resp = nil;
	    if (info.isOK) {
	        resp = responseObject;
		}
	    NSLog(@"success %@", info);
	    completeBlock(info, resp);
	}                                                                failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
	    double duration = [[NSDate date] timeIntervalSinceDate:startTime];
	    QNResponseInfo *info = [QNHttpManager buildResponseInfo:operation withError:error withDuration:duration withResponse:operation.responseData withIp:ip];
	    NSLog(@"failure %@", info);
	    completeBlock(info, nil);
	}
	    ];

	if (progressBlock) {
		[operation setUploadProgressBlock: ^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
		    progressBlock(totalBytesWritten, totalBytesExpectedToWrite);
		}];
	}
	[request setTimeoutInterval:_timeout];

	[request setValue:QNUserAgent() forHTTPHeaderField:@"User-Agent"];
	[request setValue:nil forHTTPHeaderField:@"Accept-Language"];
	[_httpManager.operationQueue addOperation:operation];
}

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock {
	
	NSMutableURLRequest *request = [_httpManager.requestSerializer
	                                multipartFormRequestWithMethod:@"POST"
	                                                     URLString:url
	                                                    parameters:params
	                                     constructingBodyWithBlock: ^(id < AFMultipartFormData > formData) {
	    [formData appendPartWithFileData:data name:@"file" fileName:key mimeType:mime];
	}

	                                                         error:nil];
	[self sendRequest:request
	    withCompleteBlock:completeBlock
	    withProgressBlock:progressBlock];
}

- (void)         post:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
          withHeaders:(NSDictionary *)headers
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock {

	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:url]];
	if (headers) {
		[request setAllHTTPHeaderFields:headers];
	}

	[request setHTTPMethod:@"POST"];

	if (params) {
		[request setValuesForKeysWithDictionary:params];
	}
	[request setHTTPBody:data];
	[self sendRequest:request
	    withCompleteBlock:completeBlock
	    withProgressBlock:progressBlock];
}

@end
