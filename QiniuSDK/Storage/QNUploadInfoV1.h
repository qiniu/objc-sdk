//
//  QNUploadInfoV1.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"
#import "QNUploadData.h"
#import "QNUploadBlock.h"
#import "QNUploadInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadInfoV1 : QNUploadInfo

+ (instancetype)info:(id <QNUploadSource>)source
       configuration:(QNConfiguration *)configuration;


+ (instancetype)info:(id <QNUploadSource>)source
          dictionary:(NSDictionary *)dictionary;

- (BOOL)isFirstData:(QNUploadData *)data;

- (QNUploadBlock *)nextUploadBlock:(NSError **)error;

- (QNUploadData *)nextUploadData:(QNUploadBlock *)block;

- (NSArray <NSString *> *)allBlocksContexts;

@end

NS_ASSUME_NONNULL_END
