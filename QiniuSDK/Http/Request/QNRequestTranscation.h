//
//  QNRequestTranscation.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class QNUpToken, QNConfiguration, QNUploadOption, QNResponseInfo, QNUploadRegionRequestMetrics;

typedef void(^QNRequestTranscationCompleteHandler)(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response);

// 单个对象只能执行一个事务，多个事务需要创建多个事务对象完成
@interface QNRequestTranscation : NSObject

//MARK:-- 构造方法
- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                      ioHosts:(NSArray <NSString *> *)ioHosts
                        token:(QNUpToken *)token;

//MARK:-- upload事务构造方法 选择
- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  targetRegion:(id <QNUploadRegion>)targetRegion
                  currentegion:(id <QNUploadRegion>)currentegion
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;
- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                       ioHosts:(NSArray <NSString *> *)ioHosts
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;

- (void)queryUploadHosts:(QNRequestTranscationCompleteHandler)complete;

- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRequestTranscationCompleteHandler)complete;

- (void)makeBlock:(long long)blockOffset
        blockSize:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(QNRequestTranscationCompleteHandler)complete;

- (void)uploadChunk:(NSString *)blockContext
        blockOffset:(long long)blockOffset
          chunkData:(NSData *)chunkData
        chunkOffest:(long long)chunkOffest
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(QNRequestTranscationCompleteHandler)complete;

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(QNRequestTranscationCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
