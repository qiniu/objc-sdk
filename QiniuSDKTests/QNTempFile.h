//
//  QNTempFile.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNTempFile : NSObject

+ (NSURL *)createTempfileWithSize:(int)size;
+ (void)removeTempfile:(NSURL *)path;

@end
