//
//  QNRequestTranscation.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadFixedHostRegion.h"

NS_ASSUME_NONNULL_BEGIN

@class QNUpToken, QNConfiguration, QNUploadOption, QNResponseInfo;
// 单个对象只能执行一个事务，多个事务需要创建多个事务对象完成
@interface QNRequestTranscation : NSObject

//MARK:-- 构造方法
- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                        token:(QNUpToken *)token;

//MARK:-- upload事务构造方法 选择
- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                        region:(id <QNUploadRegion>)region
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;
- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token;


- (void)quertUploadHosts:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)makeBlock:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)uploadChunk:(NSString *)blockContext
          chunkData:(NSData *)chunkData
        chunkOffest:(long long)chunkOffest
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

@end

NS_ASSUME_NONNULL_END
