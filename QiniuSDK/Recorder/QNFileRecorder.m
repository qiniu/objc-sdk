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

+ (instancetype)createWithFolder:(NSString *)directory
                           error:(NSError *__autoreleasing *)perror {
	[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:perror];
	if (*perror != nil) {
		return nil;
	}

	return [[QNFileRecorder alloc] initWithFolder:directory];
}

- (instancetype)initWithFolder:(NSString *)directory {
	if (self = [super init]) {
		_directory = directory;
	}
	return self;
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

- (NSError *)del:(NSString *)key {
	NSError *error;
	[[NSFileManager defaultManager] removeItemAtPath:[self pathOfKey:key] error:&error];
	return error;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p, dir: %@>", NSStringFromClass([self class]), self, _directory];
}

@end
