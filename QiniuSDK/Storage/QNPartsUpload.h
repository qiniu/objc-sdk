//
//  QNPartsUpload.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//
/// 分片上传，默认为串行

#import "QNBaseUpload.h"
#import "QNUploadInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class QNRequestTransaction;
@interface QNPartsUpload : QNBaseUpload

/// 上传剩余的数据，此方法整合上传流程，上传操作为performUploadRestData，默认串行上传
- (void)uploadRestData:(dispatch_block_t)completeHandler;
- (void)performUploadRestData:(dispatch_block_t)completeHandler;

@end

NS_ASSUME_NONNULL_END
