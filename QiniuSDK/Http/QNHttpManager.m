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

@interface QNHttpManager ()
@property AFHTTPRequestOperationManager *httpManager;
// @property  AFHTTPSessionManager *sesssionManager;
@end

@implementation QNHttpManager

- (instancetype)init {
	if (self = [super init]) {
		self.httpManager = [[AFHTTPRequestOperationManager alloc] init];
		self.httpManager.responseSerializer = [AFJSONResponseSerializer serializer];
	}

	return self;
}

+ (QNResponseInfo *)buildResponseInfo:(AFHTTPRequestOperation *)operation
                            withError:(NSError *)error {
	QNResponseInfo *info;
	if (operation.response) {
		NSDictionary *headers = [operation.response allHeaderFields];
		NSString *reqId = headers[@"X-Reqid"];
		NSString *xlog = headers[@"XLog"];
		int status =  (int)[operation.response statusCode];
		info = [[QNResponseInfo alloc] init:status withReqId:reqId withXLog:xlog withRemote:nil withBody:nil];
	}
	else {
		info = [[QNResponseInfo alloc] initWithError:error];
	}
	return info;
}

- (NSError *)sendRequest:(NSMutableURLRequest *)request
       withCompleteBlock:(QNCompleteBlock)completeBlock
       withProgressBlock:(QNInternalProgressBlock)progressBlock {
    NSLog(@"1st");
	AFHTTPRequestOperationManager *manager = self.httpManager;
	AFHTTPRequestOperation *operation = [manager
	                                     HTTPRequestOperationWithRequest:request
	                                                             success: ^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                      NSLog(@"2nd");
	    QNResponseInfo *info = [QNHttpManager buildResponseInfo:operation withError:nil];
	    NSDictionary *resp = nil;
	    if (info.stausCode == 200) {
	        resp = responseObject;
        } else {
            // todo analyze error info
        }
                                                                    
                                                                     
	    completeBlock(info, responseObject);
	}

	                                                             failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                     NSLog(@"3rd");
	    QNResponseInfo *info = [QNHttpManager buildResponseInfo:operation withError:error];
                                                                     
	    completeBlock(info, nil);
	}

	    ];
    
    NSLog(@"%@", operation);
	if (progressBlock) {
		[operation setUploadProgressBlock: ^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
		    progressBlock(totalBytesWritten, totalBytesExpectedToWrite);
		}];
	}

	[manager.operationQueue addOperation:operation];
	return nil;
}

- (NSError *)multipartPost:(NSString *)url
                  withData:(NSData *)data
                withParams:(NSDictionary *)params
              withFileName:(NSString *)key
              withMimeType:(NSString *)mime
         withCompleteBlock:(QNCompleteBlock)completeBlock
         withProgressBlock:(QNInternalProgressBlock)progressBlock
           withCancelBlock:(QNCancelBlock)cancelBlock {
	AFHTTPRequestOperationManager *manager = self.httpManager;
	NSMutableURLRequest *request = [manager.requestSerializer
	                                multipartFormRequestWithMethod:@"POST"
	                                                     URLString:url
	                                                    parameters:params
	                                     constructingBodyWithBlock: ^(id < AFMultipartFormData > formData) {
	    [formData appendPartWithFileData:data name:@"file" fileName:key mimeType:mime];
	}

	                                                         error:nil];

	[request setValue:QNUserAgent() forHTTPHeaderField:@"User-Agent"];
	return [self sendRequest:request
	           withCompleteBlock:completeBlock
	           withProgressBlock:progressBlock];
}

- (NSError *)    post:(NSString *)url
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

	[request setValue:QNUserAgent() forHTTPHeaderField:@"User-Agent"];
	[request setHTTPMethod:@"POST"];

	if (params) {
		[request setValuesForKeysWithDictionary:params];
	}

	[request setHTTPBody:data];
	return [self sendRequest:request
	           withCompleteBlock:completeBlock
	           withProgressBlock:progressBlock];
}

@end
