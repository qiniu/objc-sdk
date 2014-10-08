//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNUploadManager.h"
#import "QNBase64.h"
#import "QNConfig.h"
#import "QNResponseInfo.h"
#import "QNHttpManager.h"
#import "QNUploadOption+Private.h"

typedef void (^task)(void);

@interface QNResumeUpload ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, weak) QNHttpManager *httpManager;
@property UInt32 size;
@property (nonatomic) int retryTimes;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpCompletionHandler complete;
@property (nonatomic, strong) NSMutableArray *contexts;
@property (nonatomic, readonly, getter = isCancelled) BOOL cancelled;
@property (nonatomic, weak) id <QNRecorderDelegate> recorder;


- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
        blockSize:(UInt32)blockSize
        chunkSize:(UInt32)chunkSize
         progress:(QNInternalProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete;

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete;

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete;

@end

@implementation QNResumeUpload

- (instancetype)initWithData:(NSData *)data
                    withSize:(UInt32)size
                     withKey:(NSString *)key
                   withToken:(NSString *)token
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
                withRecorder:(id <QNRecorderDelegate> )recorder
             withHttpManager:(QNHttpManager *)http {
	if (self = [super init]) {
		_data = data;
		_size = size;
		_key = key;
		_token = [NSString stringWithFormat:@"UpToken %@", token];
		_option = option;
		_complete = block;
		_recorder = recorder;
		_httpManager = http;
		_contexts = [[NSMutableArray alloc] initWithCapacity:(size + kQNBlockSize - 1) / kQNBlockSize];
	}
	return self;
}

- (void)nextTask:(UInt32)offset {
	if (self.isCancelled) {
		self.complete([QNResponseInfo cancel], self.key, nil);
		return;
	}

	if (offset == self.size) {
		QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
			self.complete(info, self.key, resp);
		};
		[self makeFile:kQNUpHost complete:completionHandler];
		return;
	}

	UInt32 chunkSize = [self calcPutSize:offset];
	QNInternalProgressBlock progressBlock = nil;
	if (self.option && self.option.progressHandler) {
		progressBlock = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
			float percent = (float)(offset + totalBytesWritten) / (float)self.size;
			if (percent > 0.95) {
				percent = 0.95;
			}
			self.option.progressHandler(self.key, percent);
		};
	}
	QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
		if (info.error != nil) {
            if (info.stausCode == 701) {
                [self nextTask:(offset/kQNBlockSize)*kQNBlockSize];
                return;
            }
			self.complete(info, self.key, resp);
			return;
		}
		_contexts[offset / kQNBlockSize] =  resp[@"ctx"];
		[self nextTask:offset + chunkSize];
	};
	if (offset % kQNBlockSize == 0) {
		UInt32 blockSize = [self calcBlockSize:offset];
		[self makeBlock:kQNUpHost offset:offset blockSize:blockSize chunkSize:chunkSize progress:progressBlock complete:completionHandler];
		return;
	}
	NSString *context = _contexts[offset / kQNBlockSize];
	[self putChunk:kQNUpHost offset:offset size:chunkSize context:context progress:progressBlock complete:completionHandler];
}

- (UInt32)calcPutSize:(UInt32)offset {
	UInt32 left = self.size - offset;
	return left < kQNChunkSize ? left : kQNChunkSize;
}

- (UInt32)calcBlockSize:(UInt32)offset {
	UInt32 left = self.size - offset;
	return left < kQNBlockSize ? left : kQNBlockSize;
}

- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
        blockSize:(UInt32)blockSize
        chunkSize:(UInt32)chunkSize
         progress:(QNInternalProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete {
	NSData *data = [self.data subdataWithRange:NSMakeRange(offset, (unsigned int)chunkSize)];
	NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkblk/%u", uphost, blockSize];
	[self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
	NSData *data = [self.data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
	UInt32 chunkOffset = offset % kQNBlockSize;
	NSString *url = [[NSString alloc] initWithFormat:@"http://%@/bput/%@/%u", uphost, context, (unsigned int)chunkOffset];

	// Todo: check crc
	[self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (BOOL)isCancelled {
	return self.option && [self.option isCancelled];
}

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete {
	NSString *mime;

	if (!self.option || !self.option.mimeType) {
		mime = @"";
	}
	else {
		mime = [[NSString alloc] initWithFormat:@"/mimetype/%@", [QNBase64 encodeString:self.option.mimeType]];
	}

	NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkfile/%u%@", uphost, (unsigned int)self.size, mime];

	if (self.key != nil) {
		NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNBase64 encodeString:self.key]];
		url = [NSString stringWithFormat:@"%@%@", url, keyStr];
	}

	if (self.option && self.option.params) {
		NSEnumerator *e = [self.option.params keyEnumerator];

		for (id key = [e nextObject]; key != nil; key = [e nextObject]) {
			url = [NSString stringWithFormat:@"%@/%@/%@", url, key, [QNBase64 encodeString:(self.option.params)[key]]];
		}
	}

	NSMutableData *postData = [NSMutableData data];
	NSString *bodyStr = [self.contexts componentsJoinedByString:@","];
	[postData appendData:[bodyStr dataUsingEncoding:NSUTF8StringEncoding]];
	[self post:url withData:postData withCompleteBlock:complete withProgressBlock:nil];
}

- (void)         post:(NSString *)url
             withData:(NSData *)data
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock {
	NSDictionary *headers = @{ @"Authorization":self.token, @"Content-Type":@"application/octet-stream" };
	[_httpManager post:url withData:data withParams:nil withHeaders:headers withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:nil];
}

- (void)run {
	@autoreleasepool {
		[self nextTask:0];
	}
}

@end
