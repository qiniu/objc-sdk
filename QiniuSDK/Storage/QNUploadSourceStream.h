//
//  QNUploadSourceStream.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadSourceStream : NSObject <QNUploadSource>

+ (instancetype)stream:(NSInputStream *)stream;

@end

NS_ASSUME_NONNULL_END
