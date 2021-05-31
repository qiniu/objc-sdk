//
//  QNUploadSourceStream.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadSource.h"
#import "QNInputStream.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadSourceStream : NSObject <QNUploadSource>

+ (instancetype)stream:(id <QNInputStream> _Nonnull)stream
              sourceId:(NSString * _Nullable)sourceId
              fileName:(NSString * _Nullable)fileName;

@end

NS_ASSUME_NONNULL_END
