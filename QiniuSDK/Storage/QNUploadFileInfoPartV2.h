//
//  QNUploadFileInfoPartV2.h
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadFileInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadFileInfoPartV2 : QNUploadFileInfo

// 需要上传的块
@property(nonatomic, strong, readonly)NSArray <QNUploadData *> *uploadDataList;
// 上传标识符
@property(nonatomic,   copy, nullable)NSString *uploadId;
// 上传标识符有效期
@property(nonatomic, strong, nullable)NSNumber *expireAt;

- (instancetype)initWithFileSize:(long long)fileSize
                        dataSize:(long long)dataSize
                      modifyTime:(NSInteger)modifyTime;

/// 获取下一个需要上传的块
- (QNUploadData *)nextUploadData;

/// [{ "etag": "<Etag>", "partNumber": <PartNumber> }, ...],
- (NSArray <NSDictionary *> *)getPartInfoArray;

@end

NS_ASSUME_NONNULL_END
