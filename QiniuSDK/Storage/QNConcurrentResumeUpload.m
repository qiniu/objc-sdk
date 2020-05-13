//
//  QNConcurrentResumeUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/7/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNConcurrentResumeUpload.h"
#import "QNResponseInfo.h"
#import "QNAsyncRun.h"
#import "QNRequestTranscation.h"

@interface QNConcurrentResumeUpload()

@property(nonatomic, strong) dispatch_group_t uploadGroup;
@property(nonatomic, strong) dispatch_queue_t uploadQueue;

@property(nonatomic, assign) float previousPercent;
@property(nonatomic, strong)NSMutableArray <QNRequestTranscation *> *uploadTranscations;

@property(nonatomic, strong)QNResponseInfo *uploadBlockErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadBlockErrorResponse;

@end

@implementation QNConcurrentResumeUpload

- (void)prepareToUpload{
    self.uploadGroup = dispatch_group_create();
    self.uploadQueue = dispatch_queue_create("com.qiniu.concurrentUpload", DISPATCH_QUEUE_SERIAL);
    self.chunkSize = @([self.class blockSize]);
    [super prepareToUpload];
}

- (void)startToUpload{
    [super startToUpload];
    
    self.previousPercent = 0;
    self.uploadTranscations = [NSMutableArray array];
    
    NSLog(@"concurrent resume task count: %u", (unsigned int)self.config.concurrentTaskCount);
    for (int i = 0; i < self.config.concurrentTaskCount; i++) {
        dispatch_group_enter(_uploadGroup);
        dispatch_group_async(_uploadGroup, _uploadQueue, ^{
            [self uploadRestBlock:^{
                dispatch_group_leave(self.uploadGroup);
            }];
        });
    }
    dispatch_group_notify(_uploadGroup, _uploadQueue, ^{
        if ([self.uploadFileInfo isAllUploaded] == NO || self.uploadBlockErrorResponseInfo) {
            if (self.uploadBlockErrorResponseInfo.couldRetry && [self.config allowBackupHost]) {
                [self switchRegionAndUpload];
            } else {
                [self complete:self.uploadBlockErrorResponseInfo resp:self.uploadBlockErrorResponse];
            }
        } else {
            [self makeFileRequest:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
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
    });
}

- (void)uploadRestBlock:(dispatch_block_t)completeHandler{
    if (!self.uploadFileInfo) {
        QNResponseInfo *responseInfo = self.uploadBlockErrorResponseInfo ?: [QNResponseInfo responseInfoWithInvalidArgument:@"regions error"];
        [self complete:responseInfo resp:self.uploadBlockErrorResponse];
        completeHandler();
        return;
    }
    
    id <QNUploadRegion> currentRegion = [self getCurrentRegion];
    if (!currentRegion) {
        QNResponseInfo *responseInfo = self.uploadBlockErrorResponseInfo ?: [QNResponseInfo responseInfoWithInvalidArgument:@"server error"];
        [self complete:responseInfo resp:self.uploadBlockErrorResponse];
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
    };
    
    if ([chunk isFirstData]) {
        [self makeBlockRequest:block firstChunk:chunk progress:progress completeHandler:completeHandler];
    } else {
        completeHandler();
    }
}

- (void)makeBlockRequest:(QNUploadBlock *)block
              firstChunk:(QNUploadData *)chunk
                progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         completeHandler:(dispatch_block_t)completeHandler{
    
    QNRequestTranscation *transcation = [self createUploadRequestTranscation];
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
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
            [self uploadRestBlock:completeHandler];
        } else {
            self.uploadBlockErrorResponse = response;
            self.uploadBlockErrorResponseInfo = responseInfo;
            [self setCurrentRegionRequestMetrics:metrics];
            completeHandler();
        }
        [self destoryUploadRequestTranscation:transcation];
    }];
}

- (void)makeFileRequest:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    QNRequestTranscation *transcation = [self createUploadRequestTranscation];
    
    [transcation makeFile:self.uploadFileInfo.size
                 fileName:self.fileName
            blockContexts:[self.uploadFileInfo allBlocksContexts]
                 complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        
        [self setCurrentRegionRequestMetrics:metrics];
        completeHandler(responseInfo, response);
        [self destoryUploadRequestTranscation:transcation];
    }];
}

- (QNRequestTranscation *)createUploadRequestTranscation{
    QNRequestTranscation *transcation = [[QNRequestTranscation alloc] initWithConfig:self.config
                                                                        uploadOption:self.option
                                                                        targetRegion:[self getTargetRegion]
                                                                        currentegion:[self getCurrentRegion]
                                                                                 key:self.key
                                                                               token:self.token];
    [self.uploadTranscations addObject:transcation];
    return transcation;
}

- (void)destoryUploadRequestTranscation:(QNRequestTranscation *)transcation{
    if (transcation) {
        [self.uploadTranscations removeObject:transcation];
    }
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
