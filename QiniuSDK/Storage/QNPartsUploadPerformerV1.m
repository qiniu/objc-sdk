//
//  QNPartsUploadApiV1.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNRequestTransaction.h"
#import "QNUploadFileInfoPartV1.h"
#import "QNPartsUploadPerformerV1.h"

@interface QNPartsUploadPerformerV1()
@end
@implementation QNPartsUploadPerformerV1
+ (long long)blockSize{
    return 4 * 1024 * 1024;
}

- (QNUploadFileInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return [QNUploadFileInfoPartV1 infoFromDictionary:fileInfoDictionary];
}

- (QNUploadFileInfo *)getDefaultUploadFileInfo {
    return [[QNUploadFileInfoPartV1 alloc] initWithFileSize:[self.file size]
                                                  blockSize:[QNPartsUploadPerformerV1 blockSize]
                                                   dataSize:[self getUploadChunkSize]
                                                 modifyTime:[self.file modifyTime]];
}

- (void)serverInit:(void(^)(QNResponseInfo * _Nullable responseInfo,
                            QNUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler {
    QNResponseInfo *responseInfo = [QNResponseInfo successResponse];
    completeHandler(responseInfo, nil, nil);
}

- (void)uploadNextDataCompleteHandler:(void(^)(BOOL stop,
                                               QNResponseInfo * _Nullable responseInfo,
                                               QNUploadRegionRequestMetrics * _Nullable metrics,
                                               NSDictionary * _Nullable response))completeHandler {
    QNUploadFileInfoPartV1 *fileInfo = (QNUploadFileInfoPartV1 *)self.fileInfo;
    
    QNUploadBlock *block = [fileInfo nextUploadBlock];
    QNUploadData *chunk = nil;
    @synchronized (fileInfo) {
        chunk = [block nextUploadData];
        chunk.isUploading = YES;
        chunk.isCompleted = NO;
    }

    if (block == nil || chunk == nil) {
        completeHandler(YES, nil, nil, nil);
        return;
    }
    
    NSData *chunkData = [self getDataWithChunk:chunk block:block];
    if (chunkData == nil) {
        @synchronized (fileInfo) {
            chunk.isUploading = NO;
            chunk.isCompleted = NO;
        }
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithLocalIOError:@"get chunk data error"];
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    kQNWeakSelf;
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kQNStrongSelf;
        
        chunk.progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        [self notifyProgress];
    };
    if (chunk.isFirstData) {
        [self makeBlock:block firstChunk:chunk chunkData:chunkData progress:progress completeHandler:completeHandler];
    } else {
        [self uploadChunk:block chunk:chunk chunkData:chunkData progress:progress completeHandler:completeHandler];
    }
}

- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    QNUploadFileInfoPartV1 *fileInfo = (QNUploadFileInfoPartV1 *)self.fileInfo;
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction makeFile:fileInfo.size
                 fileName:self.fileName
            blockContexts:[fileInfo allBlocksContexts]
                 complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
        
        [self destroyUploadRequestTransaction:transaction];
        completeHandler(responseInfo, metrics, response);
    }];
}


- (void)makeBlock:(QNUploadBlock *)block
       firstChunk:(QNUploadData *)chunk
        chunkData:(NSData *)chunkData
         progress:(void(^)(long long totalBytesWritten,
                           long long totalBytesExpectedToWrite))progress
  completeHandler:(void(^)(BOOL stop,
                           QNResponseInfo * _Nullable responseInfo,
                           QNUploadRegionRequestMetrics * _Nullable metrics,
                           NSDictionary * _Nullable response))completeHandler {
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction makeBlock:block.offset
                 blockSize:block.size
            firstChunkData:chunkData
                  progress:progress
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
        
        [self destroyUploadRequestTransaction:transaction];
        
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self recordUploadInfo];
            completeHandler(NO, responseInfo, metrics, response);
        } else {
            chunk.isUploading = NO;
            chunk.isCompleted = NO;
            completeHandler(NO, responseInfo, metrics, response);
        }
    }];
}


- (void)uploadChunk:(QNUploadBlock *)block
              chunk:(QNUploadData *)chunk
          chunkData:(NSData *)chunkData
           progress:(void(^)(long long totalBytesWritten,
                             long long totalBytesExpectedToWrite))progress
    completeHandler:(void(^)(BOOL stop,
                             QNResponseInfo * _Nullable responseInfo,
                             QNUploadRegionRequestMetrics * _Nullable metrics,
                             NSDictionary * _Nullable response))completeHandler {
    
    chunk.isUploading = YES;
    chunk.isCompleted = NO;
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction uploadChunk:block.context
                 blockOffset:block.offset
                   chunkData:chunkData
                 chunkOffset:chunk.offset
                    progress:progress
                    complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
        
        [self destroyUploadRequestTransaction:transaction];
        
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            block.context = blockContext;
            chunk.isUploading = NO;
            chunk.isCompleted = YES;
            [self recordUploadInfo];
            completeHandler(NO, responseInfo, metrics, response);
        } else {
            chunk.isUploading = NO;
            chunk.isCompleted = NO;
            completeHandler(NO, responseInfo, metrics, response);
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

- (long long)getUploadChunkSize{
    if (self.config.useConcurrentResumeUpload) {
        return [QNPartsUploadPerformerV1 blockSize];
    } else {
        return self.config.chunkSize;
    }
}

@end
