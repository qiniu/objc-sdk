//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/6.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNResponseInfo.h"
#import "QNRequestTranscation.h"

@interface QNResumeUpload ()

@property (nonatomic, assign) float previousPercent;
@property(nonatomic, strong)QNRequestTranscation *uploadTranscation;

@property(nonatomic, strong)QNResponseInfo *uploadChunkErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadChunkErrorResponse;

@end

@implementation QNResumeUpload

- (void)startToUpload{
    [super startToUpload];
    
    self.previousPercent = 0;

    [self uploadRestChunk:^{
        
        if ([self.uploadFileInfo isAllUploaded] == NO || self.uploadChunkErrorResponseInfo) {
            if (self.uploadChunkErrorResponseInfo.couldRetry && [self.config allowBackupHost]) {
                [self switchRegionAndUpload];
            } else {
                [self complete:self.uploadChunkErrorResponseInfo resp:self.uploadChunkErrorResponse];
            }
        } else {
            [self makeFile:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
                if (responseInfo.isOK == NO) {
                    if (responseInfo.couldRetry && [self.config allowBackupHost]) {
                        [self switchRegionAndUpload];
                    } else {
                        [self complete:responseInfo resp:response];
                    }
                } else {
                    self.option.progressHandler(self.key, 1.0);
                    [self removeUploadInfoRecord];
                    [self complete:responseInfo resp:response];
                }
            }];
        }
    }];
}

- (void)uploadRestChunk:(dispatch_block_t)completeHandler{
    if (!self.uploadFileInfo) {
        QNResponseInfo *responseInfo = self.uploadChunkErrorResponseInfo ?: [QNResponseInfo responseInfoWithInvalidArgument:@"regions error"];
        [self complete:responseInfo resp:self.uploadChunkErrorResponse];
        completeHandler();
        return;
    }
    
    id <QNUploadRegion> currentRegion = [self getCurrentRegion];
    if (!currentRegion) {
        QNResponseInfo *responseInfo = self.uploadChunkErrorResponseInfo ?: [QNResponseInfo responseInfoWithInvalidArgument:@"server error"];
        [self complete:responseInfo resp:self.uploadChunkErrorResponse];
        completeHandler();
        return;
    }
    
    QNUploadData *chunk = [self.uploadFileInfo nextUploadData];
    QNUploadBlock *block = chunk ? [self.uploadFileInfo blockWithIndex:chunk.blockIndex] : nil;
    
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        chunk.progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        float percent = self.uploadFileInfo.progress;
        if (percent > 0.95) {
            percent = 0.95;
        }
        if (percent > self.previousPercent) {
            self.previousPercent = percent;
        } else {
            percent = self.previousPercent;
        }
        self.option.progressHandler(self.key, percent);
        NSLog(@"resume  progress:%lf  blockIndex:%ld chunkIndex:%ld", percent, (long)block.index, (long)chunk.index);
    };
    
    if (!chunk) {
        completeHandler();
    } else if (chunk.isFirstData) {
        [self makeBlock:block firstChunk:chunk progress:progress completeHandler:completeHandler];
    } else {
        [self uploadChunk:block chunk:chunk progress:progress completeHandler:completeHandler];
    }
}

- (void)makeBlock:(QNUploadBlock *)block
       firstChunk:(QNUploadData *)chunk
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
  completeHandler:(dispatch_block_t)completeHandler{
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    
    QNRequestTranscation *transcation = [self createUploadRequestTranscation];
    [transcation makeBlock:block.offset
                 blockSize:block.size
            firstChunkData:[self getDataWithChunk:chunk block:block]
                  progress:progress
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self recordUploadInfo];
            [self uploadRestChunk:completeHandler];
        } else {
            self.uploadChunkErrorResponse = response;
            self.uploadChunkErrorResponseInfo = responseInfo;
            [self setCurrentRegionRequestMetrics:metrics];
            completeHandler();
        }
    }];
}

- (void)uploadChunk:(QNUploadBlock *)block
              chunk:(QNUploadData *)chunk
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    completeHandler:(dispatch_block_t)completeHandler{
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    
    QNRequestTranscation *transcation = [self createUploadRequestTranscation];
    [transcation uploadChunk:block.context
                 blockOffset:block.offset
                   chunkData:[self getDataWithChunk:chunk block:block]
                 chunkOffest:chunk.offset
                    progress:progress
                    complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self recordUploadInfo];
            [self uploadRestChunk:completeHandler];
        } else {
            self.uploadChunkErrorResponse = response;
            self.uploadChunkErrorResponseInfo = responseInfo;
            [self setCurrentRegionRequestMetrics:metrics];
            completeHandler();
        }
    }];
}

- (void)makeFile:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    QNRequestTranscation *transcation = [self createUploadRequestTranscation];
    
    [transcation makeFile:self.uploadFileInfo.size
                 fileName:self.fileName
            blockContexts:[self.uploadFileInfo allBlocksContexts]
                 complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        
        [self setCurrentRegionRequestMetrics:metrics];
        completeHandler(responseInfo, response);
    }];
}

- (QNRequestTranscation *)createUploadRequestTranscation{
    QNRequestTranscation *transcation = [[QNRequestTranscation alloc] initWithConfig:self.config
                                                                        uploadOption:self.option
                                                                        targetRegion:[self getTargetRegion]
                                                                        currentegion:[self getCurrentRegion]
                                                                                 key:self.key
                                                                               token:self.token];
    self.uploadTranscation = transcation;
    return transcation;
}

- (NSData *)getDataWithChunk:(QNUploadData *)chunk block:(QNUploadBlock *)block{
    if (!self.file) {
        return nil;
    }
    return [self.file read:(long)(chunk.offset + block.offset)
                      size:(long)chunk.size
                     error:nil];
}

@end
