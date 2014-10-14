//
//  QNResponseInfo.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//


#import "QNResponseInfo.h"

const int kQNRequestCancelled = -2;
const int kQNNetworkError = -1;

static QNResponseInfo *cancelledInfo = nil;

@implementation QNResponseInfo

+ (instancetype)cancel {
	return [[QNResponseInfo alloc] initWithCancelled];
}

- (instancetype)initWithError:(NSError *)error {
	if (self = [super init]) {
		_statusCode = kQNNetworkError;
		_error = [error copy];
	}
	return self;
}

- (instancetype)initWithCancelled {
	if (self = [super init]) {
		_statusCode = kQNRequestCancelled;
		_error = [[NSError alloc] initWithDomain:@"qiniu" code:_statusCode userInfo:@{ @"error":@"cancelled by user" }];
	}
	return self;
}

- (BOOL)isCancelled {
	return _statusCode == kQNRequestCancelled;
}

- (BOOL)isOK {
	return _statusCode == 200;
}

- (BOOL)isConnectionBroken {
	return _statusCode == kQNNetworkError;
}

- (BOOL)couldRetry {
	return (_statusCode >= 500 && _statusCode < 600 && _statusCode != 579) || _statusCode == kQNNetworkError || _statusCode == 996 || _statusCode == 406;
}

- (instancetype)init:(int)status
           withReqId:(NSString *)reqId
            withXLog:(NSString *)xlog
            withBody:(NSData *)body {
	if (self = [super init]) {
		_statusCode = status;
		_reqId = [reqId copy];
		_xlog = [xlog copy];
		if (status != 200) {
			if (body == nil) {
				_error = [[NSError alloc] initWithDomain:@"qiniu" code:_statusCode userInfo:nil];
			}
			else {
				NSError *tmp;
				NSDictionary *uInfo = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableLeaves error:&tmp];
				if (tmp != nil) {
					uInfo = @{ @"error":[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] };
				}
				_error = [[NSError alloc] initWithDomain:@"qiniu" code:_statusCode userInfo:uInfo];
			}
		}
	}
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p, status: %d, requestId: %@, xlog: %@, error: %@>", NSStringFromClass([self class]), self, _statusCode, _reqId, _xlog, _error];
}

@end
