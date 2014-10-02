//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNUploadManager.h"
#import "../Common/QNBase64.h"
#import "../Common/QNConfig.h"
#import "../Http/QNResponseInfo.h"

@interface QNResumeUpload ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, weak) QNHttpManager *httpManager;
@property UInt32 size;
@property (atomic) int uploadedCount;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNCompleteBlock block;
@property (nonatomic, strong) NSArray *contexts;

- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
             size:(UInt32)size
         progress:(QNProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete;

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete;

- (void)putBlock:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete;

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete;

@end

@implementation QNResumeUpload

- (instancetype)initWithData:(NSData *)data
                    withSize:(UInt32)size
                     withKey:(NSString *)key
                   withToken:(NSString *)token
           withCompleteBlock:(QNCompleteBlock)block
                  withOption:(QNUploadOption *)option {
	if (self = [super init]) {
		self.data = data;
		self.size = size;
		self.key = key;
		self.token = token;
		self.option = option;
		self.block = block;
		self.uploadedCount = 0;
	}

	return self;
}

- (void)increaseCount {
	//todo aotmic ++
	self.uploadedCount++;
}

- (BOOL)reachEnd {
	return self.uploadedCount == [self count];
}

- (int)count {
	return (int)((self.size + kBlockSize - 1) / kBlockSize);
}

- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
             size:(UInt32)size
         progress:(QNProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete {
	NSData *data = [self.data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
	NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkblk/%u", uphost, (unsigned int)[data length]];

	[self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
	NSData *data = [self.data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
	UInt32 chunkOffset = offset % kBlockSize;
	NSString *url = [[NSString alloc] initWithFormat:@"http://%@/bput/%@/%u", uphost, context, chunkOffset];

	// Todo: check crc
	[self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

+ (UInt32)calcChunkSize:(UInt32)blockSize
                 offset:(UInt32)offset {
	UInt32 remainLength = blockSize - offset;
	return (UInt32)(kChunkSize < remainLength ? kChunkSize : remainLength);
}

- (void)putBlock:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
	QNCompleteBlock __block __weak weakChunkComplete;
	QNCompleteBlock chunkComplete;
	__block BOOL isMakeBlock = YES;
	QNProgressBlock _progressBlock =  ^(float percent) {
	};

	weakChunkComplete = chunkComplete =  ^(QNResponseInfo *info, NSDictionary *resp) {
		if (info.error) {
//            if (isMakeBlock || info.stausCode == 701) {
			complete(info, nil);
			return;
//            }
		}
		else {
			if (progressBlock != nil) {
				// calculate
			}
			isMakeBlock = NO;
			NSString *context = [resp valueForKey:@"ctx"];
			UInt32 chunkOffset = [[resp valueForKey:@"offset"] intValue];
			if (chunkOffset == size) {
				complete(info, nil);
				return;
			}
			UInt32 chunkSize = [QNResumeUpload calcChunkSize:size offset:chunkOffset];
			[self putChunk:uphost offset:offset + chunkOffset size:chunkSize context:context progress:nil complete:weakChunkComplete];
		}
	};

	UInt32 makeBlockSize = size;
	[self makeBlock:kUpHost offset:offset size:makeBlockSize progress:_progressBlock complete:chunkComplete];
}

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete {
	NSString *mime;

	if (!self.option || !self.option.mimeType) {
		mime = @"";
	}
	else {
		mime = [[NSString alloc] initWithFormat:@"/mimetype/%@", [QNBase64 encode:self.option.mimeType]];
	}

	NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkfile/%u%@", uphost, self.size, mime];

	if (self.key != nil) {
		NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNBase64 encode:self.key]];
		url = [NSString stringWithFormat:@"%@%@", url, keyStr];
	}

	if (self.option && self.option.params) {
		NSEnumerator *e = [self.option.params keyEnumerator];

		for (id key = [e nextObject]; key != nil; key = [e nextObject]) {
			url = [NSString stringWithFormat:@"%@/%@/%@", url, key, [QNBase64 encode:(self.option.params)[key]]];
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
    withProgressBlock:(QNProgressBlock)progressBlock {
	NSDictionary *headers = @{ @"Authorization":self.token, @"Content-Type":@"application/octet-stream" };

	[self.httpManager post:url withData:data withParams:nil withHeaders:headers withCompleteBlock:completeBlock withProgressBlock:progressBlock];
}

- (NSError *)run {
	@autoreleasepool {
		QNProgressBlock __block progressBlock;
		QNProgressBlock __block __weak weakProgressBlock = progressBlock = ^(float percent) {
		};

		int blockCount = [self count];

		for (int blockIndex = 0; blockIndex < blockCount; blockIndex++) {
			UInt32 offbase = blockIndex * kBlockSize;
			__block UInt32 blockSize;

			blockSize = kBlockSize;
			if (blockIndex == blockCount - 1) {
				blockSize = self.size - offbase;
			}

			QNCompleteBlock __block __weak weakBlockComplete;
			QNCompleteBlock blockComplete;
			weakBlockComplete = blockComplete = ^(QNResponseInfo *info, NSDictionary *resp)
			{
				if (info.error != nil) {
					self.block(info, nil);
					return;
				}

				if ([self reachEnd]) {
					QNCompleteBlock __block completeBlock;
					QNCompleteBlock __block __weak weakCompleteBlock = completeBlock = ^(QNResponseInfo *info, NSDictionary *resp) {
						self.block(info, resp);
					};

					[self makeFile:kUpHost complete:completeBlock];
					return;
				}
			};

			[self putBlock:kUpHost offset:offbase size:blockSize progress:weakProgressBlock complete:weakBlockComplete];
		}
	}
	return nil;
}

@end
