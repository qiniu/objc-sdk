//
//  QNConfig.m
//  QiniuSDK
//
//  Created by bailong on 14/10/3.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNConfig.h"

NSString *const kQNUndefinedKey = @"?";
NSString *const kQNUpHost = @"upload.qiniu.com";
NSString *const kQNUpHostBackup = @"up.qiniu.com";
const UInt32 kQNChunkSize = 256 * 1024;
const UInt32 kQNBlockSize = 4 * 1024 * 1024;
const UInt32 kQNPutThreshold = 512 * 1024;

const UInt32 kQNRetryMax = 3;

@implementation QNConfig

@end
