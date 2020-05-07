//
//  QNUploadRequestTranscation.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRegion.h"

NS_ASSUME_NONNULL_BEGIN

@class QNUpToken, QNConfiguration, QNUploadOption, QNResponseInfo, QNUploadChunk, QNUploadBlock;
// 单个对象只能执行一个事务，多个事务需要创建多个事务对象完成
@interface QNUploadRequestTranscation : NSObject

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                        region:(id <QNUploadRegion>)region
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;

- (void)quertUploadHosts:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)makeBlock:(UInt32)blockSize
       firstChunk:(QNUploadChunk *)firstChunk
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)uploadChunk:(NSString *)blockContext
              chunk:(QNUploadChunk *)chunk
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)makeFile:(UInt32)fileSize
        fileName:(NSString *)fileName
       blockList:(NSArray <QNUploadBlock *> *)blockList
        complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

@end

NS_ASSUME_NONNULL_END
