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
@property(nonatomic, strong, readonly)QNUploadFileInfo *uploadFileInfo;

- (void)recordUploadInfo;

- (void)removeUploadInfoRecord;


- (void)initPartFromServer:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler;

- (void)uploadDataFromServer:(QNUploadData *)data
                    progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
             completeHandler:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler;

- (void)completePartsFromServer:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler;


- (QNRequestTransaction *)createUploadRequestTransaction;

@end

NS_ASSUME_NONNULL_END