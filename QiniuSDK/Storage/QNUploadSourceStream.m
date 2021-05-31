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
@property(nonatomic, strong)id <QNInputStream> stream;

@end
@implementation QNUploadSourceStream

+ (instancetype)stream:(id <QNInputStream> _Nonnull)stream
              sourceId:(NSString * _Nullable)sourceId
              fileName:(NSString * _Nullable)fileName {
    QNUploadSourceStream *sourceStream = [[QNUploadSourceStream alloc] init];
    sourceStream.stream = stream;
    sourceStream.sourceId = sourceId;
    sourceStream.fileName = fileName;
    sourceStream.size = -1;
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

- (long)getSize {
    return self.size;
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
    while (readSize < dataSize) {
        NSData *readData = [self.stream readData:dataSize - readSize error:error];
        if (*error != nil) {
            return nil;
        }
        
        if (readData == nil) {
            isEOF = true;
            break;
        }
        
        if (readData.length > 0) {
            [data appendData:readData];
            readSize += readData.length;
        }
    }

    self.readOffset += readSize;
    if (isEOF) {
        self.size = self.readOffset;
    }
    
    return nil;
}

- (void)close {
    [self.stream close];
}

@end
