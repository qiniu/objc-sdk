//
//  QNEtag.m
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNEtag.h"
#import "QNConfig.h"

@implementation QNEtag
+ (NSString *)file:(NSString *)filePath
             error:(NSError **)error {
	@autoreleasepool {
		NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:error];
		if (*error != nil) {
			return 0;
		}
		return [QNEtag data:data];
	}
}

+ (NSString *)data:(NSData *)data {
	return nil;
}

@end
