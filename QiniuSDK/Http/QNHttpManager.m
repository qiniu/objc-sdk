//
//  QNHttpManager.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>

#import "QNHttpManager.h"
#import "QNUserAgent.h"
#import "QNResponseInfo.h"
#import "QNConfig.h"

@interface QNHttpManager ()
@property (nonatomic) AFHTTPClient *httpManager;
@property (nonatomic) AFHTTPClient *httpManagerBackup;
@property (nonatomic) NSOperationQueue *operationQueue;
@end

@implementation QNHttpManager

- (instancetype)init {
	if (self = [super init]) {
		NSString *url = [NSString stringWithFormat:@"http://%@", kQNUpHost];
		_httpManager = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:url]];
		NSString *url2 = [NSString stringWithFormat:@"http://%@", kQNUpHostBackup];
		_httpManagerBackup = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:url2]];
	}

	return self;
}

+ (QNResponseInfo *)buildResponseInfo:(AFHTTPRequestOperation *)operation
                            withError:(NSError *)error
                         withResponse:(id)responseObject {
	QNResponseInfo *info;
	if (operation.response) {
		NSDictionary *headers = [operation.response allHeaderFields];
		NSString *reqId = headers[@"X-Reqid"];
		NSString *xlog = headers[@"X-Log"];
		int status =  (int)[operation.response statusCode];
		info = [[QNResponseInfo alloc] init:status withReqId:reqId withXLog:xlog withBody:responseObject];
	}
	else {
		info = [[QNResponseInfo alloc] initWithError:error];
	}
	return info;
}

- (void)  sendRequest:(NSMutableURLRequest *)request
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock {
	AFHTTPClient *client = _httpManager;
	if ([kQNUpHostBackup isEqualToString:request.URL.host]) {
		client = _httpManagerBackup;
	}

	AFHTTPRequestOperation *operation = [client
	                                     HTTPRequestOperationWithRequest:request
	                                                             success: ^(AFHTTPRequestOperation *operation, id responseObject) {
	    QNResponseInfo *info = [QNHttpManager buildResponseInfo:operation withError:nil withResponse:operation.responseData];
	    NSDictionary *resp = nil;
	    if (info.isOK) {
	        NSError *tmp;
	        resp = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:&tmp];
		}
	    completeBlock(info, resp);
	}                                                                failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
	    QNResponseInfo *info = [QNHttpManager buildResponseInfo:operation withError:error withResponse:operation.responseData];
	    completeBlock(info, nil);
	}

	    ];

	if (progressBlock) {
		[operation setUploadProgressBlock: ^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
		    progressBlock(totalBytesWritten, totalBytesExpectedToWrite);
		}];
	}

	[request setValue:QNUserAgent() forHTTPHeaderField:@"User-Agent"];
	[request setValue:nil forHTTPHeaderField:@"Accept-Language"];
	[client.operationQueue addOperation:operation];
}

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock {
	AFHTTPClient *client = _httpManager;
	if ([url hasSuffix:kQNUpHostBackup]) {
		client = _httpManagerBackup;
	}

	NSMutableURLRequest *request = [client multipartFormRequestWithMethod:@"POST" path:@"/" parameters:nil constructingBodyWithBlock: ^(id < AFMultipartFormData > formData) {
	    [formData appendPartWithFileData:data name:@"file" fileName:key mimeType:mime];
	    for (NSString *k in params) {
	        [formData appendPartWithFormData:[params[k] dataUsingEncoding:NSUTF8StringEncoding] name:k];
		}
	}];

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
