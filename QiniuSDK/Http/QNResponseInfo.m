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
		self.error = error;
	}
	return self;
}

- (instancetype)init:(int)status
           withReqId:(NSString *)reqId
            withXLog:(NSString *)xlog
          withRemote:(NSString *)ip
            withBody:(id)body {
	if (self = [super init]) {
		self.stausCode = status;
		self.ReqId = reqId;
		self.xlog = xlog;
		self.remoteIp = ip;
	}
	return self;
}

@end
