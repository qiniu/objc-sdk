//
//  QNEtag.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNEtag : NSObject
+ (NSString *)file:(NSString *)filePath
             error:(NSError **)error;
+ (NSString *)data:(NSData *)data;
@end
