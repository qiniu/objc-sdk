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
#import "QNRequestTransaction.h"

@interface QNConcurrentResumeUpload()

@property(nonatomic, strong) dispatch_group_t uploadGroup;
@property(nonatomic, strong) dispatch_queue_t uploadQueue;

@property(nonatomic, assign) float previousPercent;
@property(nonatomic, strong)NSMutableArray <QNRequestTransaction *> *uploadTransactions;

@property(nonatomic, strong)QNResponseInfo *uploadBlockErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadBlockErrorResponse;

@end

@implementation QNConcurrentResumeUpload

- (int)prepareToUpload{
    self.uploadGroup = dispatch_group_create();
    self.uploadQueue = dispatch_queue_create("com.qiniu.concurrentUpload", DISPATCH_QUEUE_SERIAL);
    self.chunkSize = @([self.class blockSize]);
    return [super prepareToUpload];
}

- (void)startToUpload{
    [super startToUpload];
    
    self.previousPercent = 0;
    self.uploadBlockErrorResponseInfo = nil;
    self.uploadBlockErrorResponse = nil;
    self.uploadTransactions = [NSMutableArray array];
    
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
                BOOL isSwitched = [self switchRegionAndUpload];
                if (isSwitched == NO) {
                    [self complete:self.uploadBlockErrorResponseInfo response:self.uploadBlockErrorResponse];
                }
            } else {
                [self complete:self.uploadBlockErrorResponseInfo response:self.uploadBlockErrorResponse];
            }
            
        } else {
            
            [self makeFileRequest:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
                if (responseInfo.isOK == NO) {
                    if (responseInfo.couldRetry && [self.config allowBackupHost]) {
                        BOOL isSwitched = [self switchRegionAndUpload];
                        if (isSwitched == NO) {
                            [self complete:responseInfo response:response];
                        }
                    } else {
                        [self complete:responseInfo response:response];
                    }
                } else {
                    QNAsyncRunInMain(^{
                        self.option.progressHandler(self.key, 1.0);
                    });
                    [self removeUploadInfoRecord];
                    [self complete:responseInfo response:response];
                }
            }];
        }
    });
}

- (void)uploadRestBlock:(dispatch_block_t)completeHandler{
    if (!self.uploadFileInfo) {
        if (self.uploadBlockErrorResponseInfo == nil) {
            self.uploadBlockErrorResponseInfo = [QNResponseInfo responseInfoWithInvalidArgument:@"regions error"];
            self.uploadBlockErrorResponse = self.uploadBlockErrorResponseInfo.responseDictionary;
        }
        completeHandler();
        return;
    }
    
    id <QNUploadRegion> currentRegion = [self getCurrentRegion];
    if (!currentRegion) {
        if (self.uploadBlockErrorResponseInfo == nil) {
            self.uploadBlockErrorResponseInfo = [QNResponseInfo responseInfoWithInvalidArgument:@"server error"];
            self.uploadBlockErrorResponse = self.uploadBlockErrorResponseInfo.responseDictionary;
        }
        completeHandler();
        return;
    }
    
    @synchronized (self) {
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
            QNAsyncRunInMain(^{
                self.option.progressHandler(self.key, percent);
            });
        };
        
        if (chunk) {
            [self makeBlockRequest:block firstChunk:chunk progress:progress completeHandler:completeHandler];
        } else {
            completeHandler();
        }
    }
}

- (void)makeBlockRequest:(QNUploadBlock *)block
              firstChunk:(QNUploadData *)chunk
                progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         completeHandler:(dispatch_block_t)completeHandler{
    
    NSData *chunkData = [self getDataWithChunk:chunk block:block];
    if (chunkData == nil) {
        self.uploadBlockErrorResponseInfo = [QNResponseInfo responseInfoWithLocalIOError:@"get chunk data error"];
        self.uploadBlockErrorResponse = self.uploadBlockErrorResponseInfo.responseDictionary;
        completeHandler();
        return;
    }
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    [transaction makeBlock:block.offset
                 blockSize:block.size
            firstChunkData:chunkData
                  progress:progress
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self recordUploadInfo];
            [self uploadRestBlock:completeHandler];
        } else {
            chunk.isUploading = NO;
            chunk.isCompleted = NO;
            self.uploadBlockErrorResponse = response;
            self.uploadBlockErrorResponseInfo = responseInfo;
            completeHandler();
        }
        [self destroyUploadRequestTransaction:transaction];
    }];
}

- (void)makeFileRequest:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    [transaction makeFile:self.uploadFileInfo.size
                 fileName:self.fileName
            blockContexts:[self.uploadFileInfo allBlocksContexts]
                 complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        
        [self addRegionRequestMetricsOfOneFlow:metrics];
        [self destroyUploadRequestTransaction:transaction];
        completeHandler(responseInfo, response);
    }];
}

- (QNRequestTransaction *)createUploadRequestTransaction{
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithConfig:self.config
                                                                        uploadOption:self.option
                                                                        targetRegion:[self getTargetRegion]
                                                                       currentRegion:[self getCurrentRegion]
                                                                                 key:self.key
                                                                               token:self.token];
    [self.uploadTransactions addObject:transaction];
    return transaction;
}

- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction{
    if (transaction) {
        [self.uploadTransactions removeObject:transaction];
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
