//
//  QNResponseInfo.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//


#import "QNResponseInfo.h"

static QNResponseInfo *cancelledInfo = nil;

@implementation QNResponseInfo

+ (instancetype)cancel {
	return [[QNResponseInfo alloc] initWithCancelled];
}

- (instancetype)initWithError:(NSError *)error {
	if (self = [super init]) {
		_stausCode = -1;
		_error = [error copy];
	}
	return self;
}

- (instancetype)initWithCancelled {
	if (self = [super init]) {
		_stausCode = -2;
		_error = [[NSError alloc] initWithDomain:@"qiniu" code:_stausCode userInfo:@{ @"error":@"cancel by user" }];
	}
	return self;
}

- (BOOL)isCancelled {
	return _stausCode == -2;
}

- (instancetype)init:(int)status
           withReqId:(NSString *)reqId
            withXLog:(NSString *)xlog
            withBody:(id)body {
	if (self = [super init]) {
		_stausCode = status;
		_reqId = [reqId copy];
		_xlog = [xlog copy];
		NSDictionary *uInfo;
		if ([[body className] isEqualToString:@"NSString"]) {
			uInfo = @{ @"error":body };
		}
		else {
			uInfo = body;
		}
		_error = [[NSError alloc] initWithDomain:@"qiniu" code:_stausCode userInfo:uInfo];
	}
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p, status: %d, requestId: %@, xlog: %@, error: %@>", NSStringFromClass([self class]), self, _stausCode, _reqId, _xlog, _error];
}

@end
