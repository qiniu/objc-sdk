//
//  QNConfig.h
//  QiniuSDK
//
//  Created by bailong on 14-9-29.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

static const kQiniuUndefinedKey = @"?";
static const kUpHost = @"upload.qiniu.com";
static const kUpHostBackup = @"up.qiniu.com";
static const NSArray kUpIps[] = @{@"1.1.1.1", @"2.2.2.2"};
static const kChunkSize = 256 * 1024;
static const kBlockSize = 4 * 1024 * 1024;
@interface QNConfig : NSObject

@end