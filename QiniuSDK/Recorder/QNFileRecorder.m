//
//  QNFileRecorder.m
//  QiniuSDK
//
//  Created by bailong on 14/10/5.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNFileRecorder.h"

@interface QNFileRecorder  ()

@property (copy, readonly) NSString *directory;

@end

@implementation QNFileRecorder

- (NSString *)pathOfKey:(NSString *)key {
	return [[NSString alloc] initWithFormat:@"%@/%@", _directory, key];
}

- (instancetype)initWithFolder:(NSString *)directory {
	if (self = [super init]) {
		_directory = directory;
	}
	return self;
}

- (NSError *)open {
	NSError *error;
	[[NSFileManager defaultManager] createDirectoryAtPath:_directory withIntermediateDirectories:YES attributes:nil error:&error];
	return nil;
}

- (NSError *)set:(NSString *)key
            data:(NSData *)value {
	NSError *error;
	[value writeToFile:[self pathOfKey:key] options:NSDataWritingAtomic error:&error];
	return error;
}

- (NSData *)get:(NSString *)key {
	return [NSData dataWithContentsOfFile:[self pathOfKey:key]];
}

- (NSError *)remove:(NSString *)key {
	NSError *error;
	[[NSFileManager defaultManager] removeItemAtPath:[self pathOfKey:key] error:&error];
	return error;
}

- (NSError *)close {
	return nil;
}

@end
