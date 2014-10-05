//
//  QNUploadOption.m
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadOption+Private.h"
#import "QNUploadManager.h"

@implementation QNUploadOption

- (instancetype)initWithProgess:(QNUpProgressBlock)progress {
	if (self = [super init]) {
		_progress = progress;
	}
	return self;
}

- (instancetype)initWithMime:(NSString *)mimeType
                    progress:(QNUpProgressBlock)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
                 cancelToken:(QNUpCancelBlock)cancelBlock {
	if (self = [super init]) {
		_mimeType = mimeType;
		_progress = progress;
		_params = params;
		_checkCrc = check;
		_cancelToken = cancelBlock;
	}

	return self;
}

- (NSDictionary *)p_convertToPostParams {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.params];
	return params;
}

- (BOOL)isCancelled {
	return _cancelToken && _cancelToken();
}

@end
