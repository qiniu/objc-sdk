//
//  QNUploadInfo.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNErrorCode.h"
#import "QNUploadInfo.h"

@interface QNUploadInfo()

@property(nonatomic,  copy)NSString *sourceId;
@property(nonatomic, assign)long sourceSize;
@property(nonatomic,  copy)NSString *fileName;

@property(nonatomic, strong)id <QNUploadSource> source;

@end
@implementation QNUploadInfo

+ (instancetype)info:(id <QNUploadSource>)source {
    QNUploadInfo *info = [[self alloc] init];
    info.source = source;
    info.sourceSize = [source getSize];
    info.fileName = [source getFileName];
    return info;
}

- (void)setInfoFromDictionary:(NSDictionary *)dictionary {
    self.sourceSize = [dictionary[@"sourceSize"] longValue];
    self.sourceId = dictionary[@"sourceId"];
}

- (NSDictionary *)toDictionary {
    return @{@"sourceSize" : @(self.sourceSize),
             @"sourceId" : self.sourceId ?: @""};
}

- (BOOL)hasValidResource {
    return self.source != nil;
}

- (BOOL)isValid {
    return [self hasValidResource];
}

- (BOOL)couldReloadSource {
    return [self.source couldReloadSource];
}

- (BOOL)reloadSource {
    return [self.source reloadSource];
}

- (NSString *)getSourceId {
    return [self.source getId];
}

- (long)getSourceSize {
    return [self.source getSize];
}

- (BOOL)isSameUploadInfo:(QNUploadInfo *)info {
    if (info == nil || ((self.sourceId.length > 0 || info.sourceId.length > 0) && ![self.sourceId isEqualToString:info.sourceId])) {
        return false;
    }
    
    // 检测文件大小，如果能获取到文件大小的话，就进行检测
    if (info.sourceSize > kQNUnknownSourceSize &&
        self.sourceSize > kQNUnknownSourceSize &&
        info.sourceSize != self.sourceSize) {
        return false;
    }

    return true;
}

- (long long)uploadSize {
    return 0;
}

- (BOOL)isAllUploaded {
    return true;
}

- (void)clearUploadState {
}

- (void)checkInfoStateAndUpdate {
}

- (NSData *)readData:(NSInteger)dataSize dataOffset:(long)dataOffset error:(NSError **)error {
    if (!self.source) {
        *error = [NSError errorWithDomain:NSStreamSOCKSErrorDomain code:kQNLocalIOError userInfo:@{NSLocalizedDescriptionKey : @"file is not exist"}];
        return nil;
    }
    
    NSData *data = [self.source readData:dataSize dataOffset:dataOffset error:error];
    if (error == nil && data != nil && (data.length == 0 || data.length != dataSize)) {
        self.sourceSize = data.length + dataOffset;
    }
    return data;
}

- (void)close {
    [self.source close];
}

@end

