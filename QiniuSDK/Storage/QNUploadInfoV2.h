//
//  QNUploadInfoV2.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/13.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"
#import "QNUploadData.h"
#import "QNUploadInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadInfoV2 : QNUploadInfo

@property(nonatomic,   copy, nullable)NSString *uploadId;
@property(nonatomic, strong, nullable)NSNumber *expireAt;

+ (instancetype)info:(id <QNUploadSource>)source
       configuration:(QNConfiguration *)configuration;


+ (instancetype)info:(id <QNUploadSource>)source
          dictionary:(NSDictionary *)dictionary;

- (QNUploadData *)nextUploadData:(NSError **)error;

- (NSInteger)getPartIndexOfData:(QNUploadData *)data;

- (NSArray <NSDictionary <NSString *, NSObject *> *> *)getPartInfoArray;

@end

NS_ASSUME_NONNULL_END
