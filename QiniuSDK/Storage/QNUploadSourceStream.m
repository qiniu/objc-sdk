//
//  QNUploadSourceStream.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNErrorCode.h"
#import "QNUploadSourceStream.h"

@interface QNUploadSourceStream()

@property(nonatomic, assign)BOOL hasSize;
@property(nonatomic, assign)long long size;
@property(nonatomic, assign)long long readOffset;
@property(nonatomic,   copy)NSString *sourceId;
@property(nonatomic,   copy)NSString *fileName;
@property(nonatomic, strong)NSInputStream *stream;

@end
@implementation QNUploadSourceStream

+ (instancetype)stream:(NSInputStream * _Nonnull)stream
              sourceId:(NSString * _Nullable)sourceId
                  size:(long long)size
              fileName:(NSString * _Nullable)fileName {
    QNUploadSourceStream *sourceStream = [[QNUploadSourceStream alloc] init];
    sourceStream.stream = stream;
    sourceStream.sourceId = sourceId;
    sourceStream.fileName = fileName;
    sourceStream.size = size;
    sourceStream.hasSize = size > 0;
    sourceStream.readOffset = 0;
    return sourceStream;
}

- (NSString *)getId {
    return self.sourceId;
}

- (BOOL)couldReloadSource {
    return false;
}

- (BOOL)reloadSource {
    return false;
}

- (NSString *)getFileName {
    return self.fileName;
}

- (long long)getSize {
    if (self.size > kQNUnknownSourceSize) {
        return self.size;
    } else {
        return kQNUnknownSourceSize;
    }
}

- (NSData *)readData:(NSInteger)dataSize dataOffset:(long long)dataOffset error:(NSError **)error {
    if (self.stream == nil) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : @"inputStream is empty"}];
        return nil;
    }
    
    if (dataOffset < self.readOffset) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : @"read data error: error data offset"}];
        return nil;
    }
    
    // 打开流
    [self openStreamIfNeeded];
    
    if (dataOffset > self.readOffset) {
        // 跳过多余的数据
        [self streamSkipSize:dataOffset - self.readOffset error:error];
        if (*error != nil) {
            return nil;
        }
        self.readOffset = dataOffset;
    }
    
    // 读取数据
    BOOL isEOF = false;
    NSInteger sliceSize = 1024;
    NSInteger readSize = 0;
    NSMutableData *data = [NSMutableData data];
    while (readSize < dataSize) {
        @autoreleasepool {
            NSData *sliceData = [self readDataFromStream:sliceSize error:error];
            if (*error != nil) {
                break;
            }
            
            if (sliceData.length > 0) {
                readSize += sliceData.length;
                [data appendData:sliceData];
            }
            
            if (sliceData.length < sliceSize) {
                isEOF = true;
                break;
            }
        }
    }
    

    self.readOffset += readSize;
    
    if (*error != nil) {
        return nil;
    }
    
    if (isEOF) {
        self.size = self.readOffset;
    }
    
    return data;
}

- (void)openStreamIfNeeded {
    BOOL isOpening = true;
    while (true) {
        switch (self.stream.streamStatus) {
            case NSStreamStatusNotOpen:
                [self.stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
                [self.stream open];
                continue;
            case NSStreamStatusOpening:
                continue;
            default:
                isOpening = false;
                break;
        }
        
        if (!isOpening) {
            break;
        }
    }
}

- (void)streamSkipSize:(long long)size error:(NSError **)error {
    BOOL isEOF = false;
    NSInteger sliceSize = 1024;
    NSInteger readSize = 0;
    while (readSize < size) {
        @autoreleasepool {
            NSData *sliceData = [self readDataFromStream:sliceSize error:error];
            if (*error != nil) {
                break;
            }
            
            if (sliceData.length > 0) {
                readSize += sliceData.length;
            }
            
            if (sliceData.length < sliceSize) {
                isEOF = true;
                break;
            }
            sliceData = nil;
        }
    }
}

// read 之前必须先 open stream
- (NSData *)readDataFromStream:(NSInteger)dataSize error:(NSError **)error {
    BOOL isEOF = false;
    NSInteger readSize = 0;
    NSMutableData *data = [NSMutableData data];
    uint8_t buffer[dataSize];
    while (readSize < dataSize) {
        // 检查状态
        switch (self.stream.streamStatus) {
            case NSStreamStatusOpen:
                break;
            case NSStreamStatusReading:
                continue;
            case NSStreamStatusWriting:
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : @"stream is writing"}];
                break;
            case NSStreamStatusAtEnd:
                isEOF = true;
                break;
            case NSStreamStatusClosed:
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : @"stream is closed"}];
                break;
            case NSStreamStatusError:
                *error = self.stream.streamError;
                break;
            default:
                break;
        }
        if (*error != nil) {
            return nil;
        }
        
        if (isEOF) {
            break;
        }
        
        // 检查是否有数据可读
        if (!self.stream.hasBytesAvailable) {
            [NSThread sleepForTimeInterval:0.05];
            continue;
        }
        
        // 读取数据
        NSInteger maxLength = dataSize;
        NSInteger length = [self.stream read:buffer maxLength:maxLength];
        *error = self.stream.streamError;
        if (*error != nil) {
            return nil;
        }
        
        if (length > 0) {
            readSize += length;
            [data appendBytes:(const void *)buffer length:length];
        }
    }
    return [data copy];
}

- (void)close {
    [self.stream close];
    [self.stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (NSString *)sourceType {
    return [NSString stringWithFormat:@"SourceStream:%@", _hasSize?@"HasSize":@"NoSize"];
}
@end
