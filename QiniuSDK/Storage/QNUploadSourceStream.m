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

@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger readOffset;
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
    return sourceStream;
}

- (NSString *)getId {
    return self.sourceId;
}

- (BOOL)couldReloadSource {
    return false;
}

- (BOOL)reloadSource {
    self.readOffset = 0;
    return false;
}

- (NSString *)getFileName {
    return self.fileName;
}

- (long)getSize {
    if (self.size > kQNUnknownSourceSize) {
        return self.size;
    } else {
        return kQNUnknownSourceSize;
    }
}

- (NSData *)readData:(NSInteger)dataSize dataOffset:(long)dataOffset error:(NSError **)error {
    if (self.stream == nil) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : @"inputStream is empty"}];
        return nil;
    }
    
    if (dataOffset != self.readOffset) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : @"read data error: error data offset"}];
        return nil;
    }
    
    BOOL isEOF = false;
    NSInteger readSize = 0;
    NSMutableData *data = [NSMutableData data];
    uint8_t buffer[1024];
    while (readSize < dataSize) {
        switch (self.stream.streamStatus) {
            case NSStreamStatusNotOpen:
                [self open];
                continue;
            case NSStreamStatusOpening:
                continue;
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
        
        if (!self.stream.hasBytesAvailable) {
            [NSThread sleepForTimeInterval:0.05];
            continue;
        }
        
        NSInteger maxLength = 1024;
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

    self.readOffset += readSize;
    if (isEOF) {
        self.size = self.readOffset;
    }
    
    return data;
}

- (void)open {
    [self.stream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.stream open];
}

- (void)close {
    [self.stream close];
    [self.stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

@end
