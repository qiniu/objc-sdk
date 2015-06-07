//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "QNConfiguration.h"
#import "QNHttpManager.h"
#import "QNSessionManager.h"
#import "QNResponseInfo.h"
#import "QNCrc32.h"
#import "QNUploadManager.h"
#import "QNResumeUpload.h"
#import "QNFormUpload.h"
#import "QNUploadOption+Private.h"
#import "QNAsyncRun.h"
#import "QNUpToken.h"

@interface QNUploadManager ()
@property (nonatomic) id <QNHttpDelegate> httpManager;
@property (nonatomic) QNConfiguration *config;
//@property (nonatomic) id <QNRecorderDelegate> recorder;
//@property (nonatomic, strong) QNRecorderKeyGenerator recorderKeyGen;
@end

@implementation QNUploadManager

- (instancetype)init {
	return [self initWithConfiguration:nil];
}

- (instancetype)initWithRecorder:(id <QNRecorderDelegate> )recorder {
	return [self initWithRecorder:recorder recorderKeyGenerator:nil];
}

- (instancetype)initWithRecorder:(id <QNRecorderDelegate> )recorder
            recorderKeyGenerator:(QNRecorderKeyGenerator)recorderKeyGenerator {
	QNConfiguration *config = [QNConfiguration build: ^(QNConfigurationBuilder *builder) {
	    builder.recorder = recorder;
	    builder.recorderKeyGen = recorderKeyGenerator;
	}];
	return [self initWithConfiguration:config];
}

- (instancetype)initWithConfiguration:(QNConfiguration *)config {
	if (self = [super init]) {
		if (config == nil) {
			config = [QNConfiguration build: ^(QNConfigurationBuilder *builder) {
			}];
		}
		_config = config;
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
		BOOL lowVersion = NO;
	#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
		float sysVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
		if (sysVersion < 7.0) {
			lowVersion = YES;
		}
	#else
		NSOperatingSystemVersion sysVersion = [[NSProcessInfo processInfo] operatingSystemVersion];

		if ((sysVersion.majorVersion = 10 && sysVersion.minorVersion < 9)) {
			lowVersion = YES;
		}
	#endif
		if (lowVersion) {
			_httpManager = [[QNHttpManager alloc] initWithTimeout:config.timeoutInterval urlConverter:config.converter backupIp:config.upIp];
		}
		else {
			_httpManager = [[QNSessionManager alloc] initWithProxy:config.proxy timeout:config.timeoutInterval
			                                          urlConverter:config.converter backupIp:config.upIp];
		}
#else
		_httpManager = [[QNHttpManager alloc] initWithTimeout:config.timeoutInterval urlConverter:config.converter backupIp:config.upIp];
#endif
	}
	return self;
}

+ (instancetype)sharedInstanceWithConfiguration:(QNConfiguration *)config {
	static QNUploadManager *sharedInstance = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] initWithConfiguration:config];
	});

	return sharedInstance;
}

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                       data:(NSData *)data
                       file:(NSString *)file
                   complete:(QNUpCompletionHandler)completionHandler {
	NSString *desc = nil;
	if (completionHandler == nil) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException
		                               reason:@"no completionHandler" userInfo:nil];
		return YES;
	}
	if (data == nil && file == nil) {
		desc = @"no input data";
	}
	else if (token == nil || [token isEqualToString:@""]) {
		desc = @"no token";
	}
	if (desc != nil) {
		QNAsyncRunInMain( ^{
			completionHandler([QNResponseInfo responseInfoWithInvalidArgument:desc], key, nil);
		});
		return YES;
	}
	return NO;
}

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
	if ([QNUploadManager checkAndNotifyError:key token:token data:data file:nil complete:completionHandler]) {
		return;
	}

	QNUpToken *t = [QNUpToken parse:token];
	if (t == nil) {
		QNAsyncRunInMain( ^{
			completionHandler([QNResponseInfo responseInfoWithInvalidToken:@"invalid token"], key, nil);
		});
		return;
	}

	QNUpCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp)
	{
		QNAsyncRunInMain( ^{
			completionHandler(info, key, resp);
		});
	};
	QNFormUpload *up = [[QNFormUpload alloc]
	                    initWithData:data
	                              withKey:key
	                            withToken:t
	                withCompletionHandler:complete
	                           withOption:option
	                      withHttpManager:_httpManager
	                    withConfiguration:_config];
	QNAsyncRun( ^{
		[up put];
	});
}

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
	if ([QNUploadManager checkAndNotifyError:key token:token data:nil file:filePath complete:completionHandler]) {
		return;
	}

	@autoreleasepool {
		QNUpToken *t = [QNUpToken parse:token];
		if (t == nil) {
			QNAsyncRunInMain( ^{
				completionHandler([QNResponseInfo responseInfoWithInvalidToken:@"invalid token"], key, nil);
			});
			return;
		}

		NSError *error = nil;
		NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];

		if (error) {
			QNAsyncRunInMain( ^{
				QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
				completionHandler(info, key, nil);
			});
			return;
		}

		NSNumber *fileSizeNumber = fileAttr[NSFileSize];
		UInt32 fileSize = [fileSizeNumber intValue];
		NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
		if (error) {
			QNAsyncRunInMain( ^{
				QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
				completionHandler(info, key, nil);
			});
			return;
		}
		if (fileSize <= _config.putThreshold) {
			[self putData:data key:key token:token complete:completionHandler option:option];
			return;
		}

		QNUpCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp)
		{
			QNAsyncRunInMain( ^{
				completionHandler(info, key, resp);
			});
		};

		NSDate *modifyTime = fileAttr[NSFileModificationDate];
		NSString *recorderKey = key;
		if (_config.recorder != nil && _config.recorderKeyGen != nil) {
			recorderKey = _config.recorderKeyGen(key, filePath);
		}

		NSLog(@"recorder %@", _config.recorder);

		QNResumeUpload *up = [[QNResumeUpload alloc]
		                      initWithData:data
		                               withSize:fileSize
		                                withKey:key
		                              withToken:t
		                  withCompletionHandler:complete
		                             withOption:option
		                         withModifyTime:modifyTime
		                           withRecorder:_config.recorder
		                        withRecorderKey:recorderKey
		                        withHttpManager:_httpManager
		                      withConfiguration:_config];
		QNAsyncRun( ^{
			[up run];
		});
	}
}

@end
