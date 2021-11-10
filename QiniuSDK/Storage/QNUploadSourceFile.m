//
//  QNUploadSourceFile.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadSourceFile.h"

@interface QNUploadSourceFile()

@property(nonatomic, strong)id <QNFileDelegate> file;

@end
@implementation QNUploadSourceFile

+ (instancetype)file:(id <QNFileDelegate>)file {
    QNUploadSourceFile *sourceFile = [[QNUploadSourceFile alloc] init];
    sourceFile.file = file;
    return sourceFile;
}


- (BOOL)couldReloadSource {
    return self.file != nil;
}

- (BOOL)reloadSource {
    return true;
}

- (nonnull NSString *)getId {
    return [NSString stringWithFormat:@"%@_%lld", [self getFileName], [self.file modifyTime]];
}

- (nonnull NSString *)getFileName {
    return [[self.file path] lastPathComponent];
}

- (long long)getSize {
    return [self.file size];
}

- (NSData *)readData:(NSInteger)dataSize dataOffset:(long long)dataOffset error:(NSError *__autoreleasing  _Nullable *)error {
    return [self.file read:dataOffset size:dataSize error:error];
}

- (void)close {
    [self.file close];
}

- (NSString *)sourceType {
    if ([self.file respondsToSelector:@selector(fileType)]) {
        return self.file.fileType;
    } else {
        return @"SourceFile";
    }
}
@end
