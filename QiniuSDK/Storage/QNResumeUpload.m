//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/6.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNResponseInfo.h"
#import "QNUploadRequestTranscation.h"

@interface QNResumeUpload ()

@property (nonatomic, assign) float previousPercent;
@property(nonatomic, strong)QNUploadRequestTranscation *uploadTranscation;

@property(nonatomic, strong)QNResponseInfo *errorResponseInfo;
@property(nonatomic, strong)NSDictionary *errorResponse;

@end

@implementation QNResumeUpload

- (void)startToUpload{
    [self nextStep];
}

- (void)nextStep{
    if (!self.uploadFileInfo) {
        if (self.completionHandler) {
            QNResponseInfo *respinseInfo = self.errorResponseInfo ?: [QNResponseInfo responseInfoWithInvalidArgument:@"regions error" duration:0];
            self.completionHandler(respinseInfo, self.key, self.errorResponse);
        }
        return;
    }
    
    id <QNUploadRegion> currentRegion = [self getCurrentRegion];
    if (!currentRegion) {
        if (self.completionHandler) {
            QNResponseInfo *respinseInfo = self.errorResponseInfo ?: [QNResponseInfo responseInfoWithInvalidArgument:@"server error" duration:0];
            self.completionHandler(respinseInfo, self.key, self.errorResponse);
        }
        return;
    }
    
    self.uploadTranscation = [[QNUploadRequestTranscation alloc] initWithConfig:self.config
                                                                   uploadOption:self.option
                                                                         region:self.getCurrentRegion
                                                                            key:self.key
                                                                          token:self.token];
    
    QNUploadData *chunk = [self.uploadFileInfo nextUploadData];
    QNUploadBlock *block = chunk ? [self.uploadFileInfo blockWithIndex:chunk.blockIndex] : nil;
    
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        float percent = (float)(chunk.offset + totalBytesWritten) / (float)self.uploadFileInfo.size;
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
    
    if (!chunk && [self.uploadFileInfo isAllUploaded]){
        [self makeFile:block firstChunk:chunk progress:progress];
    } else if ([chunk isFirstData]) {
        [self makeBlock:block firstChunk:chunk progress:progress];
    } else if(chunk){
        [self uploadChunk:block chunk:chunk progress:progress];
    }
}

- (void)makeBlock:(QNUploadBlock *)block
       firstChunk:(QNUploadData *)chunk
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress{
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    [self.uploadTranscation makeBlock:block.size
                       firstChunkData:[self getDataWithChunk:chunk block:block]
                             progress:progress
                             complete:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            [self recordUploadInfo];
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self nextStep];
        } else if (responseInfo.couldRetry && self.config.allowBackupHost) {
            [self switchRegionAndUpload];
        } else {
            self.completionHandler(responseInfo, self.key, response);
        }
    }];
}

- (void)uploadChunk:(QNUploadBlock *)block
              chunk:(QNUploadData *)chunk
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress{
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    [self.uploadTranscation uploadChunk:block.context
                              chunkData:[self getDataWithChunk:chunk block:block]
                            chunkOffest:chunk.offset
                               progress:progress
                               complete:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            [self recordUploadInfo];
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self nextStep];
        } else if (responseInfo.couldRetry && self.config.allowBackupHost) {
            [self switchRegionAndUpload];
        } else {
            self.completionHandler(responseInfo, self.key, response);
        }
    }];
}

- (void)makeFile:(QNUploadBlock *)block
      firstChunk:(QNUploadData *)chunk
        progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress{
    
    [self.uploadTranscation makeFile:self.uploadFileInfo.size
                            fileName:self.fileName
                       blockContexts:[self.uploadFileInfo allBlocksContexts]
                            complete:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        if (responseInfo.isOK) {
            [self removeUploadInfoRecord];
            progress(self.uploadFileInfo.size, self.uploadFileInfo.size);
            self.completionHandler(responseInfo, self.key, response);
        } else if (responseInfo.couldRetry && self.config.allowBackupHost) {
            [self switchRegionAndUpload];
        } else {
            self.completionHandler(responseInfo, self.key, response);
        }
    }];
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
