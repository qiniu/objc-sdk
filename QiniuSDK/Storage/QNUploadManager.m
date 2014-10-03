//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "../Common/QNConfig.h"
#import "../Http/QNHttpManager.h"
#import "../Http/QNResponseInfo.h"

#import "QNUploadManager.h"
#import "QNResumeUpload.h"

@interface QNUploadOption ()
@property (nonatomic, readonly, copy) NSDictionary *convertToPostParams;
@end

@implementation QNUploadOption

- (NSMutableDictionary *)convertToPostParams {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.params];

	return params;
}

@end

@interface QNUploadManager ()
@property QNHttpManager *httpManager;
@end

@implementation QNUploadManager

- (instancetype)init {
	if (self = [super init]) {
		_httpManager = [[QNHttpManager alloc] init];
	}

	return self;
}

- (void)      putData:(NSData *)data
              withKey:(NSString *)key
            withToken:(NSString *)token
    withCompleteBlock:(QNUpCompleteBlock)block
           withOption:(QNUploadOption *)option {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

	if (key && ![key isEqualToString:kQNUndefinedKey]) {
		parameters[@"key"] = key;
	}

	if (!key) {
		key = kQNUndefinedKey;
	}

	parameters[@"token"] = token;

	if (option.params) {
		[parameters addEntriesFromDictionary:option.convertToPostParams];
	}

	NSString *mimeType = option.mimeType;

	if (!mimeType) {
		mimeType = @"application/octet-stream";
	}

	QNInternalProgressBlock p = nil;

	if (option && option.progress) {
		p = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
			float percent = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
			if (percent > 0.95) {
				percent = 0.95;
			}
			option.progress(key, percent);
		};
	}

	QNCompleteBlock _block = ^(QNResponseInfo *info, NSDictionary *resp)
	{
		if (p) {
			option.progress(key, 1.0);
		}
		block(info, key, resp);
	};

	[_httpManager multipartPost:[NSString stringWithFormat:@"http://%@", kQNUpHost]
	                   withData:data
	                 withParams:parameters
	               withFileName:key
	               withMimeType:mimeType
	          withCompleteBlock:_block
	          withProgressBlock:p
	            withCancelBlock:nil];
}

- (void)      putFile:(NSString *)filePath
              withKey:(NSString *)key
            withToken:(NSString *)token
    withCompleteBlock:(QNUpCompleteBlock)block
           withOption:(QNUploadOption *)option {
	@autoreleasepool {
		NSError *error = nil;
		NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];

		if (error) {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
			    QNResponseInfo *info = [[QNResponseInfo alloc] initWithError:error];
			    block(info, key, nil);
			});
			return;
		}

		NSNumber *fileSizeNumber = fileAttr[NSFileSize];
		UInt32 fileSize = [fileSizeNumber intValue];
		NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
		if (error) {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
			    QNResponseInfo *info = [[QNResponseInfo alloc] initWithError:error];
			    block(info, key, nil);
			});
			return;
		}
		if (fileSize <= kQNPutThreshHold) {
			[self putData:data withKey:key withToken:token withCompleteBlock:block withOption:option];
		}

		QNUpCompleteBlock _block = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp)
		{
			block(info, key, resp);
		};

		QNResumeUpload *up = [[QNResumeUpload alloc]
		                      initWithData:data
		                                  withSize:fileSize
		                                   withKey:key
		                                 withToken:token
		                         withCompleteBlock:_block
		                                withOption:option];

		[up run];
	}
}

@end
