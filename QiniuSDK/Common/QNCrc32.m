//
//  QNCrc.m
//  QiniuSDK
//
//  Created by bailong on 14-9-29.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <zlib.h>

#import "QNCrc32.h"

@implementation QNCrc32

+ (UInt32)data:(NSData *)data {
	uLong crc = crc32(0L, Z_NULL, 0);

	crc = crc32(crc, [data bytes], (uInt)[data length]);
	return (UInt32)crc;
}

+ (UInt32)file:(NSString *)filePath
         error:(NSError **)error {
	@autoreleasepool {
		NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:error];
		if (*error != nil) {
			return 0;
		}
		return [QNCrc32 data:data];
	}
}

@end
