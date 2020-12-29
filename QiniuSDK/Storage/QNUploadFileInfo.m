//
//  QNUploadData.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//
#import "QNUploadFileInfo.h"

@interface QNUploadData()

@property(nonatomic, assign)long long offset;
@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger index;

@end
@implementation QNUploadData

+ (instancetype)dataFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
         
    QNUploadData *data = [[QNUploadData alloc] init];
    data.offset     = [dictionary[@"offset"] longLongValue];
    data.size       = [dictionary[@"size"] longLongValue];
    data.index      = [dictionary[@"index"] integerValue];
    data.etag       = dictionary[@"etag"];
    data.isCompleted = [dictionary[@"isCompleted"] boolValue];
    if (data.isCompleted) {
        data.progress = 1;
    } else {
        data.progress = 0;
    }
    return data;
}

- (instancetype)initWithOffset:(long long)offset
                      dataSize:(long long)dataSize
                         index:(NSInteger)index {
    if (self = [super init]) {
        _offset = offset;
        _size = dataSize;
        _index = index;
        _etag = nil;
        _isCompleted = NO;
        _progress = 0;
    }
    return self;
}

- (BOOL)isFirstData{
    return self.index == 1;
}

- (void)clearUploadState{
    self.isCompleted = NO;
    self.isUploading = NO;
    self.etag = nil;
}

- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"offset"]      = @(self.offset);
    dictionary[@"size"]        = @(self.size);
    dictionary[@"index"]       = @(self.index);
    dictionary[@"etag"]        = self.etag;
    dictionary[@"isCompleted"] = @(self.isCompleted);
    return [dictionary copy];
}

@end


@interface QNUploadFileInfo()

@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger modifyTime;

@end
@implementation QNUploadFileInfo

+ (instancetype)infoFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    QNUploadFileInfo *fileInfo = [[self alloc] init];
    fileInfo.size = [dictionary[@"size"] longLongValue];
    fileInfo.modifyTime = [dictionary[@"modifyTime"] integerValue];
    
    return fileInfo;
}

- (void)clearUploadState{
}

- (BOOL)isAllUploaded{
    return NO;
}

- (float)progress{
    return 0;
}

- (BOOL)isEmpty{
    return NO;
}

- (BOOL)isValid{
    return YES;
}

- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"size"] = @(self.size);
    dictionary[@"modifyTime"] = @(self.modifyTime);

    return [dictionary copy];
}

@end
