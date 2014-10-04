//
//  QNResponseInfo.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//


#import "QNResponseInfo.h"

@implementation QNResponseInfo

- (instancetype)initWithError:(NSError *)error {
	if (self = [super init]) {
		_stausCode = -1;
		_error = [error copy];
	}
	return self;
}

- (instancetype)init:(int)status
           withReqId:(NSString *)reqId
            withXLog:(NSString *)xlog
            withBody:(id)body {
	if (self = [super init]) {
		_stausCode = status;
		_reqId = [reqId copy];
		_xlog = [xlog copy];
		_error = [[NSError alloc] initWithDomain:@"qiniu" code:_stausCode userInfo:body];
	}
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p, status: %d, requestId: %@, xlog: %@, error: %@>", NSStringFromClass([self class]), self, _stausCode, _reqId, _xlog, _error];
}

@end
