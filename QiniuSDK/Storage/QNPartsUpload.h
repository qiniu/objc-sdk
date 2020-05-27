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

@interface QNPartsUpload : QNBaseUpload

@property(nonatomic, assign, readonly, class)long long blockSize;
// 定制chunk大小 在执行run之前赋值
@property(nonatomic, strong)NSNumber *chunkSize;
@property(nonatomic, strong, readonly)QNUploadFileInfo *uploadFileInfo;

- (void)recordUploadInfo;

- (void)removeUploadInfoRecord;

@end

NS_ASSUME_NONNULL_END
