//
//  QNTempFile.m
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNTempFile.h"

@implementation QNTempFile

+ (NSURL *)createTempfileWithSize:(int)size {
	NSString *fileName = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], @"file.txt"];
	NSURL *fileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
	NSData *data = [NSMutableData dataWithLength:size];
	NSError *error = nil;
	[data writeToURL:fileUrl options:NSDataWritingAtomic error:&error];
	return fileUrl;
}

+ (void)removeTempfile:(NSURL *)fileUrl {
	NSError *error = nil;
	[[NSFileManager defaultManager] removeItemAtURL:fileUrl error:&error];
}

@end
