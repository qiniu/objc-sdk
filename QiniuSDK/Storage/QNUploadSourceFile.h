//
//  QNUploadSourceFile.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNFileDelegate.h"
#import "QNUploadSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadSourceFile : NSObject <QNUploadSource>

+ (instancetype)file:(id <QNFileDelegate>)file;

@end

NS_ASSUME_NONNULL_END
