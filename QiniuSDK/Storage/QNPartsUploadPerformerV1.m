//
//  QNPartsUploadApiV1.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNLogUtil.h"
#import "QNDefine.h"
#import "QNRequestTransaction.h"
#import "QNUploadInfoV1.h"
#import "QNPartsUploadPerformerV1.h"

@interface QNPartsUploadPerformerV1()
@end
@implementation QNPartsUploadPerformerV1
+ (long long)blockSize{
    return 4 * 1024 * 1024;
}

- (QNUploadInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return [QNUploadInfoV1 info:self.uploadSource dictionary:fileInfoDictionary];
}

- (QNUploadInfo *)getDefaultUploadInfo {
    return [QNUploadInfoV1 info:self.uploadSource configuration:self.config];
}

- (void)serverInit:(void(^)(QNResponseInfo * _Nullable responseInfo,
                            QNUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler {
    QNResponseInfo *responseInfo = [QNResponseInfo successResponse];
    completeHandler(responseInfo, nil, nil);
}

- (void)uploadNextData:(void(^)(BOOL stop,
                                QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    QNUploadInfoV1 *uploadInfo = (QNUploadInfoV1 *)self.uploadInfo;
    
    NSError *error;
    QNUploadBlock *block = nil;
    QNUploadData *chunk = nil;
    @synchronized (self) {
        block = [uploadInfo nextUploadBlock:&error];
        chunk = [uploadInfo nextUploadData:block];
        chunk.state = QNUploadStateUploading;
    }

    if (error) {
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithLocalIOError:[NSString stringWithFormat:@"%@", error]];
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    if (block == nil || chunk == nil) {
        QNLogInfo(@"key:%@ no chunk left", self.key);
        
        QNResponseInfo *responseInfo = nil;
        if (uploadInfo.getSourceSize == 0) {
            responseInfo = [QNResponseInfo responseInfoOfZeroData:@"file is empty"];
        } else {
            responseInfo = [QNResponseInfo responseInfoWithSDKInteriorError:@"no chunk left"];
        }
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    kQNWeakSelf;
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kQNStrongSelf;
        chunk.uploadSize = totalBytesWritten;
        [self notifyProgress:false];
    };
    
    void (^completeHandlerP)(QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        NSString *blockContext = response[@"ctx"];
        if (responseInfo.isOK && blockContext) {
            block.context = blockContext;
            chunk.state = QNUploadStateComplete;
            [self recordUploadInfo];
            [self notifyProgress:false];
        } else {
            chunk.state = QNUploadStateWaitToUpload;
        }
        completeHandler(NO, responseInfo, metrics, response);
    };
    
    if ([uploadInfo isFirstData:chunk]) {
        QNLogInfo(@"key:%@ makeBlock", self.key);
        [self makeBlock:block firstChunk:chunk chunkData:chunk.data progress:progress completeHandler:completeHandlerP];
    } else {
        QNLogInfo(@"key:%@ uploadChunk", self.key);
        [self uploadChunk:block chunk:chunk chunkData:chunk.data progress:progress completeHandler:completeHandlerP];
    }
}

- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    QNUploadInfoV1 *uploadInfo = (QNUploadInfoV1 *)self.uploadInfo;
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction makeFile:[uploadInfo getSourceSize]
                 fileName:self.fileName
            blockContexts:[uploadInfo allBlocksContexts]
                 complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
        if (responseInfo.isOK) {
            [self notifyProgress:true];
        }
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}


- (void)makeBlock:(QNUploadBlock *)block
       firstChunk:(QNUploadData *)chunk
        chunkData:(NSData *)chunkData
         progress:(void(^)(long long totalBytesWritten,
                           long long totalBytesExpectedToWrite))progress
  completeHandler:(void(^)(QNResponseInfo * _Nullable responseInfo,
                           QNUploadRegionRequestMetrics * _Nullable metrics,
                           NSDictionary * _Nullable response))completeHandler {
    
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
        
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}


- (void)uploadChunk:(QNUploadBlock *)block
              chunk:(QNUploadData *)chunk
          chunkData:(NSData *)chunkData
           progress:(void(^)(long long totalBytesWritten,
                             long long totalBytesExpectedToWrite))progress
    completeHandler:(void(^)(QNResponseInfo * _Nullable responseInfo,
                             QNUploadRegionRequestMetrics * _Nullable metrics,
                             NSDictionary * _Nullable response))completeHandler {
    
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
        
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}

@end
