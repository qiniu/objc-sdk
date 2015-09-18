//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNUploadManager.h"
#import "QNUrlSafeBase64.h"
#import "QNConfiguration.h"
#import "QNResponseInfo.h"
#import "QNHttpManager.h"
#import "QNUploadOption+Private.h"
#import "QNRecorderDelegate.h"
#import "QNCrc32.h"
#import "QNTaskRecord.h"
#import "QNAsyncRun.h"

typedef void (^task)(void);

@interface QNResumeUpload ()

@property (nonatomic, strong) id <QNHttpDelegate> httpManager;
@property UInt32 size;
@property (nonatomic) int retryTimes;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *recorderKey;
@property (nonatomic) NSDictionary *headers;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic, strong) QNUpCompletionHandler complete;

@property int64_t modifyTime;
@property (nonatomic, strong) id <QNRecorderDelegate> recorder;

@property (nonatomic, strong) QNConfiguration *config;

@property (nonatomic, strong) id <QNFileDelegate> file;
@property (nonatomic, copy) NSArray *tasks;
@property (atomic, assign) UInt32 uploadedSize;

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete;

@end

@implementation QNResumeUpload

- (instancetype) initWithFile:(id <QNFileDelegate> )file
                      withKey:(NSString *)key
                    withToken:(QNUpToken *)token
        withCompletionHandler:(QNUpCompletionHandler)block
                   withOption:(QNUploadOption *)option
                 withRecorder:(id <QNRecorderDelegate> )recorder
              withRecorderKey:(NSString *)recorderKey
              withHttpManager:(id <QNHttpDelegate> )http
            withConfiguration:(QNConfiguration *)config;
{
	if (self = [super init]) {
		_file = file;
		_size = (UInt32)[file size];
		_key = key;
		NSString *tokenUp = [NSString stringWithFormat:@"UpToken %@", token.token];
		_option = option != nil ? option :[QNUploadOption defaultOptions];
		_complete = block;
		_headers = @{ @"Authorization":tokenUp, @"Content-Type":@"application/octet-stream" };
		_recorder = recorder;
		_httpManager = http;
		_modifyTime = [file modifyTime];
		_recorderKey = recorderKey;
		_config = config;

		_token = token;
	}
	return self;
}

// save json value
//{
//    "size":filesize,
//    "offset":lastSuccessOffset,
//    "modify_time": lastFileModifyTime,
//    "contexts": contexts
//}

- (void)recordTasks {
	NSString *key = self.recorderKey;
	if (self.tasks.count == 0 || _recorder == nil || key == nil || [key isEqualToString:@""]) {
		return;
	}
    
	NSNumber *n_size = @(self.size);
	NSNumber *n_time = [NSNumber numberWithLongLong:_modifyTime];
    NSMutableArray *taskDics = [NSMutableArray arrayWithCapacity:self.tasks.count];
    [self.tasks enumerateObjectsUsingBlock:^(QNTaskRecord*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dic = [obj jsonFromObj];
        if (dic) {
            [taskDics addObject:dic];
        }
    }];
    
	NSMutableDictionary *rec = [NSMutableDictionary dictionaryWithObjectsAndKeys:n_size, @"size", taskDics, @"tasks", n_time, @"modify_time", nil];

	NSError *error;
	NSData *data = [NSJSONSerialization dataWithJSONObject:rec options:NSJSONWritingPrettyPrinted error:&error];
	if (error != nil) {
		NSLog(@"up record json error %@ %@", key, error);
		return;
	}
	
    @synchronized(self.recorder) {
        error = [_recorder set:key data:data];
    }
    
	if (error != nil) {
		NSLog(@"up record set error %@ %@", key, error);
	}
}

- (void)removeRecord {
	if (_recorder == nil) {
		return;
	}
	[_recorder del:self.recorderKey];
}

- (void)recoveryFromRecord {
	NSString *key = self.recorderKey;
	if (_recorder == nil || key == nil || [key isEqualToString:@""]) {
        [self createEmptyTasks];
		return;
	}
    
	NSData *data = [_recorder get:key];
	if (data == nil) {
        [self createEmptyTasks];
		return ;
	}

	NSError *error;
	NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
	if (error != nil) {
		NSLog(@"recovery error %@ %@", key, error);
		[_recorder del:self.key];
        
        [self createEmptyTasks];
		return ;
	}
	NSArray *taskDics = info[@"tasks"];
	NSNumber *n_size = info[@"size"];
	NSNumber *time = info[@"modify_time"];
	if (taskDics == nil || n_size == nil || time == nil) {
        [self createEmptyTasks];
		return;
	}
    
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:taskDics.count];
    for (NSDictionary *dic in taskDics) {
        QNTaskRecord *record = [QNTaskRecord recordFromJson:dic];
        if (record) {
            [tasks addObject:record];
        }
    }
    
    int blockCount = (self.size + kQNBlockSize - 1) / kQNBlockSize;
    if (tasks.count != blockCount) {
        [self createEmptyTasks];
        return;
    }
    self.tasks = tasks;
    
    self.uploadedSize = 0;
    [self.tasks enumerateObjectsUsingBlock:^(QNTaskRecord*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        self.uploadedSize += obj.offset - obj.blockIndex * kQNBlockSize;
        obj.running = NO;
    }];
    
	UInt32 size = [n_size unsignedIntValue];
	if (size != self.size) {
        [self createEmptyTasks];
		return;
	}
    
    
	UInt64 t = [time unsignedLongLongValue];
	if (t != _modifyTime) {
		NSLog(@"modify time changed %llu, %llu", t, _modifyTime);
        [self createEmptyTasks];
		return;
	}
    
	return;
}

- (void)createEmptyTasks
{
    int blockCount = (self.size + kQNBlockSize - 1) / kQNBlockSize;
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:blockCount];
    for (int i = 0; i < blockCount; i++) {
        QNTaskRecord *task = [[QNTaskRecord alloc] init];
        task.blockIndex = i;
        task.offset = i * kQNBlockSize;
        [tasks addObject:task];
    }
    self.tasks = tasks;
}

- (BOOL)allTaskFinished
{
    __block BOOL finished = YES;
    @synchronized(self) {
        [self.tasks enumerateObjectsUsingBlock:^(QNTaskRecord*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ((idx + 1 != self.tasks.count && obj.isFinished == NO) || (idx + 1 == self.tasks.count && obj.offset != self.size)) {
                finished = NO;
            }
        }];
    }
    
    return finished;
}

- (void)nextTask:(QNTaskRecord*)task retriedTimes:(int)retried host:(NSString *)host {
	if (self.option.cancellationSignal()) {
		self.complete([QNResponseInfo cancel], self.key, nil);
		return;
	}
    task.running = YES;

	UInt32 chunkSize = [self calcPutSize:task.offset];
	QNInternalProgressBlock progressBlock = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        
        float percent = (float)(self.uploadedSize + totalBytesWritten) / (float)self.size;
        
        if (percent > 0.95) {
            percent = 0.95;
        }
        self.option.progressHandler(self.key, percent);
	};

	QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
		if (info.error != nil) {
			if (info.statusCode == 701) {
                task.offset = task.blockIndex * kQNBlockSize;
				[self nextTask:task retriedTimes:0 host:host];
				return;
			}
			if (retried >= _config.retryMax || !info.couldRetry) {
				self.complete(info, self.key, resp);
				return;
			}

			NSString *nextHost = host;
			if (info.isConnectionBroken || info.needSwitchServer) {
				nextHost = _config.upHostBackup;
			}

			[self nextTask:task retriedTimes:retried + 1 host:nextHost];
			return;
		}

		if (resp == nil) {
			[self nextTask:task retriedTimes:retried host:host];
			return;
		}

		NSString *ctx = resp[@"ctx"];
		NSNumber *crc = resp[@"crc32"];
		if (ctx == nil || crc == nil || [crc unsignedLongValue] != task.chunkCrc) {
			[self nextTask:task retriedTimes:retried host:host];
			return;
		}
        
		task.context = ctx;
        task.offset += chunkSize;
        @synchronized(self) {
            self.uploadedSize += chunkSize;
        }
		QNAsyncRun(^{
            [self recordTasks];
        });
		[self nextTask:task retriedTimes:retried host:host];
	};
    
	if (task.offset % kQNBlockSize == 0 || task.offset == self.size) {
        if (task.offset == task.blockIndex * kQNBlockSize) {
            UInt32 blockSize = [self calcBlockSize:task.offset];
            [self makeBlock:host task:task blockSize:blockSize chunkSize:chunkSize progress:progressBlock complete:completionHandler];
        }
        else {
            if ([self allTaskFinished]) {
                [self postFinished:host retriedTimes:0];
                return;
            }
            else {
                task.running = NO;
                [self runNextTask];
            }
        }

		return;
	}
	NSString *context = task.context;
	[self putChunk:host task:task size:chunkSize context:context progress:progressBlock complete:completionHandler];
}

- (void)postFinished:(NSString*)host retriedTimes:(int)retried
{
    QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
        if (info.isOK) {
            [self removeRecord];
            self.option.progressHandler(self.key, 1.0);
        }
        else if (info.couldRetry && retried < _config.retryMax) {
            [self postFinished:host retriedTimes:retried + 1];
            return;
        }
        self.complete(info, self.key, resp);
    };
    [self makeFile:host complete:completionHandler];
}

- (UInt32)calcPutSize:(UInt32)offset {
	UInt32 left = self.size - offset;
	return left < _config.chunkSize ? left : _config.chunkSize;
}

- (UInt32)calcBlockSize:(UInt32)offset {
	UInt32 left = self.size - offset;
	return left < kQNBlockSize ? left : kQNBlockSize;
}

- (void)makeBlock:(NSString *)uphost
             task:(QNTaskRecord*)task
        blockSize:(UInt32)blockSize
        chunkSize:(UInt32)chunkSize
         progress:(QNInternalProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete {
	NSData *data = [self.file read:task.offset size:chunkSize];
    NSString *url = nil;
    if (self.config.isEnabledBackgroundUpload) {
        url = [[NSString alloc] initWithFormat:@"http://%@/mkblk/%u", uphost, (unsigned int)blockSize];
    }
    else {
        url = [[NSString alloc] initWithFormat:@"http://%@:%u/mkblk/%u", uphost, (unsigned int)_config.upPort, (unsigned int)blockSize];
    }
	task.chunkCrc = [QNCrc32 data:data];
	[self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putChunk:(NSString *)uphost
            task:(QNTaskRecord*)task
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
	NSData *data = [self.file read:task.offset size:size];
	UInt32 chunkOffset = task.offset % kQNBlockSize;
	NSString *url = nil;
    if (self.config.isEnabledBackgroundUpload) {
        url = [[NSString alloc] initWithFormat:@"http://%@/bput/%@/%u", uphost, context, (unsigned int)chunkOffset];
    }
    else {
        url = [[NSString alloc] initWithFormat:@"http://%@:%u/bput/%@/%u", uphost, (unsigned int)_config.upPort, context, (unsigned int)chunkOffset];
    }
	task.chunkCrc = [QNCrc32 data:data];
	[self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete {
	NSString *mime = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.option.mimeType]];

    __block NSString *url = nil;
    if (self.config.isEnabledBackgroundUpload) {
        url = [[NSString alloc] initWithFormat:@"http://%@/mkfile/%u%@", uphost, (unsigned int)self.size, mime];
    }
    else {
        url = [[NSString alloc] initWithFormat:@"http://%@:%u/mkfile/%u%@", uphost, (unsigned int)_config.upPort, (unsigned int)self.size, mime];
    }

	if (self.key != nil) {
		NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNUrlSafeBase64 encodeString:self.key]];
		url = [NSString stringWithFormat:@"%@%@", url, keyStr];
	}

	[self.option.params enumerateKeysAndObjectsUsingBlock: ^(NSString *key, NSString *obj, BOOL *stop) {
	         url = [NSString stringWithFormat:@"%@/%@/%@", url, key, [QNUrlSafeBase64 encodeString:obj]];
	 }];


	NSMutableData *postData = [NSMutableData data];
	__block NSString *bodyStr = nil;
    [self.tasks enumerateObjectsUsingBlock:^(QNTaskRecord*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (bodyStr) {
            bodyStr = [bodyStr stringByAppendingFormat:@",%@",obj.context];
        }
        else {
            bodyStr = obj.context;
        }
    }];
	[postData appendData:[bodyStr dataUsingEncoding:NSUTF8StringEncoding]];
	[self post:url withData:postData withCompleteBlock:complete withProgressBlock:nil];
}

- (void)             post:(NSString *)url
                 withData:(NSData *)data
        withCompleteBlock:(QNCompleteBlock)completeBlock
        withProgressBlock:(QNInternalProgressBlock)progressBlock {
	[_httpManager post:url withData:data withParams:nil withHeaders:_headers withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:_option.cancellationSignal];
}

- (void)run {
	@autoreleasepool {
		[self recoveryFromRecord];
        
        if ([self allTaskFinished]) {
            [self postFinished:self.config.upHost retriedTimes:0];
        }
        else {
            for (int i = 0; i < self.config.maxUploadThreadCount; i++) {
                [self runNextTask];
            }
        }
	}
}

- (void)runNextTask
{
    @synchronized(self) {
        [self.tasks enumerateObjectsUsingBlock:^(QNTaskRecord*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!obj.isRunning && obj.isFinished == NO) {
                if (idx +1 != self.tasks.count || obj.offset != self.size) {
                    [self nextTask:obj retriedTimes:0 host:self.config.upHost];
                    *stop = YES;
                }
            }
        }];
    }
}

@end
