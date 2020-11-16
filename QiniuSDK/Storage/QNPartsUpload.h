//
//  QNPartsUpload.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNBaseUpload.h"
#import "QNUploadFileInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class QNRequestTransaction;
@interface QNPartsUpload : QNBaseUpload

// 定制data大小 在执行run之前赋值
@property(nonatomic, strong)NSNumber *dataSize;
/// 块大小 分块和并发分块大小可能不通
@property(nonatomic, assign, readonly, class)long long blockSize;
/// 定制chunk大小 在执行run之前赋值
@property(nonatomic, strong)NSNumber *chunkSize;
/// 上传信息
@property(nonatomic, strong, readonly)QNUploadFileInfo *uploadFileInfo;

- (void)recordUploadInfo;

- (void)removeUploadInfoRecord;


- (void)initPartToServer:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler;

- (void)uploadDataToServer:(QNUploadData *)data
                  progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           completeHandler:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler;

- (void)completePartsToServer:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler;


- (QNRequestTransaction *)createUploadRequestTransaction;
- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
