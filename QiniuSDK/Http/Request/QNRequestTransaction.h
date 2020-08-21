//
//  QNRequestTransaction.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class QNUpToken, QNConfiguration, QNUploadOption, QNResponseInfo, QNUploadRegionRequestMetrics;

typedef void(^QNRequestTransactionCompleteHandler)(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response);

// 单个对象只能执行一个事务，多个事务需要创建多个事务对象完成
@interface QNRequestTransaction : NSObject

//MARK:-- 构造方法
- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                     regionId:(NSString * _Nullable)regionId
                        token:(QNUpToken *)token;

//MARK:-- upload事务构造方法 选择
- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  targetRegion:(id <QNUploadRegion>)targetRegion
                 currentRegion:(id <QNUploadRegion>)currentRegion
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;
- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                      regionId:(NSString * _Nullable)regionId
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;

- (void)queryUploadHosts:(QNRequestTransactionCompleteHandler)complete;

- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRequestTransactionCompleteHandler)complete;

- (void)makeBlock:(long long)blockOffset
        blockSize:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(QNRequestTransactionCompleteHandler)complete;

- (void)uploadChunk:(NSString *)blockContext
        blockOffset:(long long)blockOffset
          chunkData:(NSData *)chunkData
        chunkOffset:(long long)chunkOffset
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(QNRequestTransactionCompleteHandler)complete;

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(QNRequestTransactionCompleteHandler)complete;

@end

NS_ASSUME_NONNULL_END
