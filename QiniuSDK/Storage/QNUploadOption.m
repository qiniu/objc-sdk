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

- (instancetype)initWithProgessHandler:(QNUpProgressHandler)progress {
	if (self = [super init]) {
		_progressHandler = progress;
	}
	return self;
}

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(QNUpProgressHandler)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
          cancellationSignal:(QNUpCancellationSignal)cancel {
	if (self = [super init]) {
		_mimeType = mimeType;
		_progressHandler = progress;
		_params = params;
		_checkCrc = check;
		_cancellationSignal = cancel;
	}

	return self;
}

- (NSDictionary *)p_convertToPostParams {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.params];
	return params;
}

- (BOOL)isCancelled {
	return _cancellationSignal && _cancellationSignal();
}

@end
