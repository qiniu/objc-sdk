//
//  QNPartsUpload.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNBaseUpload.h"
#import "QNUploadData.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNPartsUpload : QNBaseUpload

@property(nonatomic, strong, readonly)QNUploadFileInfo *uploadFileInfo;

- (void)recordUploadInfo;

- (void)removeUploadInfoRecord;

@end

NS_ASSUME_NONNULL_END
