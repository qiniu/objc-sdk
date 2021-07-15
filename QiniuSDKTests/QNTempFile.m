//
//  QNTempFile.m
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNTempFile.h"
#import "QNEtag.h"

@interface QNTempFile()

@property(nonatomic, strong)NSInputStream *inputStream;
@property(nonatomic, strong)NSData *data;
@property(nonatomic,  copy)NSString *fileHash;

@end
@implementation QNTempFile

- (instancetype)init{
    if (self = [super init]) {
        _canRemove = YES;
    }
    return self;
}

- (NSInputStream *)inputStream {
    if (_inputStream == nil || _inputStream.streamStatus == NSStreamStatusClosed) {
        _inputStream = [NSInputStream inputStreamWithURL:self.fileUrl];
    }
    return _inputStream;
}

- (NSData *)data {
    if (_data == nil) {
        _data = [NSData dataWithContentsOfURL:self.fileUrl];
    }
    return _data;
}

- (long long)size {
    if (self.fileType == QNTempFileTypeStreamNoSize) {
        return -1;
    } else {
        return _size;
    }
}

+ (QNTempFile *)createTempFileWithSize:(int)size {
    
    return [self createTempFileWithSize:size name:@"file.txt"];
}

+ (QNTempFile *)createTempFileWithSize:(int)size name:(NSString *)name {
    
    NSString *fileName = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], name];
    NSURL *fileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    
    NSMutableData *data = [NSMutableData data];
    int count = 128;
    NSMutableArray *words = [NSMutableArray array];
    @autoreleasepool {
        for (int i=0; i< count; i++) {
            NSMutableString *word = [NSMutableString string];
            for (int j=0; j<6; j++) {
                NSString *charString = [[NSString alloc] initWithFormat:@"%c", arc4random()%count];
                [word appendFormat:@"_%@", charString];
            }
            [words addObject:word];
        }
        while ([data length] < size) {
            NSString *content = [words componentsJoinedByString:words[arc4random()%count]];
            [data appendData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }

    NSError *error = nil;
    NSData *dataReal = [data subdataWithRange:NSMakeRange(0, size)];
    [dataReal writeToURL:fileUrl options:NSDataWritingAtomic error:&error];
    
    QNTempFile *file = [[QNTempFile alloc] init];
    file.fileUrl = fileUrl;
    file.fileHash = [QNEtag data:data];
    file.size = size;
    return file;
}


+ (QNTempFile *)createTempFileWithSize:(int)size identifier:(NSString *)identifier{
    return [self createTempFileWithSize:size name:@"file.txt" identifier:identifier];
}

+ (QNTempFile *)createTempFileWithSize:(int)size name:(NSString *)name identifier:(NSString *)identifier {
    
    NSString *identifierP = identifier ?: @"_";
    
    NSString *fileName = [NSString stringWithFormat:@"/%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], name];
    NSURL *fileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    
    NSMutableData *data = [NSMutableData data];
    int count = 128;
    NSMutableArray *words = [NSMutableArray array];
    @autoreleasepool {
        for (int i=0; i< count; i++) {
            NSMutableString *word = [NSMutableString string];
            for (int j=0; j<6; j++) {
                [word appendFormat:@"[%c%@%c]", i, identifierP, j];
            }
            [words addObject:word];
        }
        int index = 0;
        while ([data length] < size) {
            NSString *content = [words componentsJoinedByString:words[index%count]];
            [data appendData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            index ++;
        }
    }

    NSError *error = nil;
    NSData *dataReal = [data subdataWithRange:NSMakeRange(0, size)];
    [dataReal writeToURL:fileUrl options:NSDataWritingAtomic error:&error];
    
    QNTempFile *file = [[QNTempFile alloc] init];
    file.fileUrl = fileUrl;
    file.fileHash = [QNEtag file:fileUrl.path error:nil];
    file.size = size;
    return file;
}

- (void)remove{
    if (self.canRemove) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:self.fileUrl error:&error];
    }
}

@end
