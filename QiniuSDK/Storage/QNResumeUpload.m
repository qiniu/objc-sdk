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

@interface QNResumeUpload ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, weak) QNHttpManager *httpManager;
@property UInt32 size;
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
	}

	return self;
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

- (void)putBlock:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
	QNCompleteBlock _completeBlock =  ^(QNResponseInfo *info, NSDictionary *resp) {
	};
	QNProgressBlock _progressBlock =  ^(float percent) {
	};
	UInt32 makeBlockSize = size;
	[self makeBlock:kUpHost offset:offset size:makeBlockSize progress:_progressBlock complete:_completeBlock];

//    __block UInt32 bodyLength = self.chunkSize < blockSize ? self.chunkSize : blockSize;
//    __block QiniuBlkputRet *blockPutRet;
//    __block UInt32 retryTime = self.retryTime;
//    __block BOOL isMkblock = YES;
//
//    QNCompleteBlock __block __weak weakChunkComplete;
//    QNCompleteBlock chunkComplete;
//    weakChunkComplete = chunkComplete = ^(AFHTTPRequestOperation *operation, NSError *error)
//    {
//        if (error != nil) {
//
//            if (retryTime == 0 || isMkblock || [operation.response statusCode] == 701) {
//                complete(operation, error);
//                return;
//            } else {
//                retryTime --;
//            }
//        } else {
//            if (progressBlock != nil) {
//                progressBlock([extra chunkUploadedAndPercent]);
//            }
//            retryTime = self.retryTime;
//            isMkblock = NO;
//            blockPutRet = [[QiniuBlkputRet alloc] initWithDictionary:operation.responseObject];
//
//            UInt32 remainLength = blockSize - blockPutRet.offset;
//            bodyLength = self.chunkSize < remainLength ? self.chunkSize : remainLength;
//        }
//
//        if (blockPutRet.offset == blockSize) {
//            complete(operation, nil);
//            return;
//        }
//
//        [self chunkPut:mappedData
//           blockPutRet:blockPutRet
//            offsetBase:offsetBase
//            bodyLength:bodyLength
//              progress:progressBlock
//              complete:weakChunkComplete];
//    };
//
//    [self mkblock:mappedData
//       offsetBase:offsetBase
//        blockSize:blockSize
//       bodyLength:bodyLength
//           uphost:uphost
//         progress:progressBlock
//         complete:chunkComplete];
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
	return nil;
}

@end
