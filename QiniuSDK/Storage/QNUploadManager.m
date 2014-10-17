//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QNConfig.h"
#import "QNHttpManager.h"
#import "QNResponseInfo.h"
#import "QNCrc32.h"
#import "QNUploadManager.h"
#import "QNResumeUpload.h"
#import "QNUploadOption+Private.h"
#import "QNAsyncRun.h"

@interface QNUploadManager ()
@property (nonatomic) QNHttpManager *httpManager;
@property (nonatomic) id <QNRecorderDelegate> recorder;
@property (nonatomic, strong) QNRecorderKeyGenerator recorderKeyGen;
@end

@implementation QNUploadManager

- (instancetype)init {
	return [self initWithRecorder:nil recorderKeyGenerator:nil];
}

- (instancetype)initWithRecorder:(id <QNRecorderDelegate> )recorder {
	return [self initWithRecorder:recorder recorderKeyGenerator:nil];
}

- (instancetype)initWithRecorder:(id <QNRecorderDelegate> )recorder
            recorderKeyGenerator:(QNRecorderKeyGenerator)recorderKeyGenerator {
	if (self = [super init]) {
		_httpManager = [[QNHttpManager alloc] init];
		_recorder = recorder;
		_recorderKeyGen = recorderKeyGenerator;
	}
	return self;
}

+ (instancetype)sharedInstanceWithRecorder:(id <QNRecorderDelegate> )recorder
                      recorderKeyGenerator:(QNRecorderKeyGenerator)recorderKeyGenerator {
	static QNUploadManager *sharedInstance = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    sharedInstance = [[self alloc] initWithRecorder:recorder recorderKeyGenerator:recorderKeyGenerator];
	});

	return sharedInstance;
}

+ (BOOL)checkAndNotifyError:(NSString*)key
                      token:(NSString*)token
                      data:(NSData*)data
                       file:(NSString *)file
complete:(QNUpCompletionHandler)completionHandler {
    NSString *desc = nil;
    if (completionHandler == nil) {
        // todo throe excetpion
        //NSException *e = [NSEx];
        return YES;
    }
    if (data == nil && file == nil) {
        desc = @"no input data";
    }else if (token == nil || [token isEqualToString:@""] ){
        desc = @"no token";
    }
    if (desc != nil) {
        QNAsyncRun(^{
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
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if ([QNUploadManager checkAndNotifyError:key token:token data:data file:nil complete:completionHandler]){
        return;
    }

	if (key && ![key isEqualToString:kQNUndefinedKey]) {
		parameters[@"key"] = key;
	}

	if (!key) {
		key = kQNUndefinedKey;
	}

	parameters[@"token"] = token;

	if (option && option.params) {
		[parameters addEntriesFromDictionary:option.params];
	}

	NSString *mimeType = option.mimeType;

	if (!mimeType) {
		mimeType = @"application/octet-stream";
	}

	if (option && option.checkCrc) {
		parameters[@"crc32"] = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:data]];
	}

	QNInternalProgressBlock p = nil;

	if (option && option.progressHandler) {
		p = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
			float percent = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
			if (percent > 0.95) {
				percent = 0.95;
			}
			option.progressHandler(key, percent);
		};
	}

	QNCompleteBlock complete = ^(QNResponseInfo *info, NSDictionary *resp)
	{
		if (info.isOK && p) {
			option.progressHandler(key, 1.0);
		}
		if (info.isOK || !info.couldRetry) {
			completionHandler(info, key, resp);
			return;
		}
		NSString *nextHost = kQNUpHost;
		if (info.isConnectionBroken) {
			nextHost = kQNUpHostBackup;
		}

		QNCompleteBlock retriedComplete = ^(QNResponseInfo *info, NSDictionary *resp) {
			if (info.isOK && p) {
				option.progressHandler(key, 1.0);
			}
			completionHandler(info, key, resp);
		};

		[_httpManager multipartPost:[NSString stringWithFormat:@"http://%@", nextHost]
		                   withData:data
		                 withParams:parameters
		               withFileName:key
		               withMimeType:mimeType
		          withCompleteBlock:retriedComplete
		          withProgressBlock:p
		            withCancelBlock:nil];
	};

	[_httpManager multipartPost:[NSString stringWithFormat:@"http://%@", kQNUpHost]
	                   withData:data
	                 withParams:parameters
	               withFileName:key
	               withMimeType:mimeType
	          withCompleteBlock:complete
	          withProgressBlock:p
	            withCancelBlock:nil];
}

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
    if ([QNUploadManager checkAndNotifyError:key token:token data:nil file:filePath complete:completionHandler]){
        return;
    }

	@autoreleasepool {
		NSError *error = nil;
		NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];

		if (error) {
			QNAsyncRun(^{
                QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
			    completionHandler(info, key, nil);
			});
			return;
		}

		NSNumber *fileSizeNumber = fileAttr[NSFileSize];
		UInt32 fileSize = [fileSizeNumber intValue];
		NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
		if (error) {
			QNAsyncRun(^{
			    QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
			    completionHandler(info, key, nil);
			});
			return;
		}
		if (fileSize <= kQNPutThreshold) {
			[self putData:data key:key token:token complete:completionHandler option:option];
			return;
		}

		QNUpCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp)
		{
			completionHandler(info, key, resp);
		};

		NSDate *modifyTime = fileAttr[NSFileModificationDate];
		NSString *recorderKey = key;
		if (_recorder != nil && _recorderKeyGen != nil) {
			recorderKey = _recorderKeyGen(key, filePath);
		}

		QNResumeUpload *up = [[QNResumeUpload alloc]
		                      initWithData:data
		                                      withSize:fileSize
		                                       withKey:key
		                                     withToken:token
		                         withCompletionHandler:complete
		                                    withOption:option
		                                withModifyTime:modifyTime
		                                  withRecorder:_recorder
		                               withRecorderKey:recorderKey
		                               withHttpManager:_httpManager];
		QNAsyncRun(^{
            [up run];
        });
	}
}

@end
