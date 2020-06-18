//
//  QNUploadRequestInfo.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/13.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadRequestInfo : NSObject

/// 当前请求的类型
@property(nonatomic,   copy, nullable)NSString *requestType;

/// 上传的bucket
@property(nonatomic,   copy, nullable)NSString *bucket;
/// 上传的key
@property(nonatomic,   copy, nullable)NSString *key;
/// 上传数据的偏移量
@property(nonatomic, strong, nullable)NSNumber *fileOffset;
/// 上传的目标region
@property(nonatomic,   copy, nullable)NSString *targetRegionId;
/// 当前上传的region
@property(nonatomic,   copy, nullable)NSString *currentRegionId;

- (BOOL)shouldReportRequestLog;

@end

extern NSString *const QNUploadRequestTypeUCQuery;
extern NSString *const QNUploadRequestTypeForm;
extern NSString *const QNUploadRequestTypeMkblk;
extern NSString *const QNUploadRequestTypeBput;
extern NSString *const QNUploadRequestTypeMkfile;
extern NSString * const QNUploadRequestTypeUpLog;

NS_ASSUME_NONNULL_END
