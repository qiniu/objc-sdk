//
//  QNUploadData.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadData.h"

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
    data.offset = [dictionary[@"offset"] longLongValue];
    data.size   = [dictionary[@"size"] longLongValue];
    data.index  = [dictionary[@"index"] integerValue];
    data.etag   = dictionary[@"etag"];
    data.md5    = dictionary[@"md5"];
    data.state  = [dictionary[@"state"] intValue];
    return data;
}

- (instancetype)initWithOffset:(long long)offset
                      dataSize:(long long)dataSize
                         index:(NSInteger)index {
    if (self = [super init]) {
        _offset = offset;
        _size = dataSize;
        _index = index;
        _etag = @"";
        _md5 = @"";
        _state = QNUploadStateNeedToCheck;
    }
    return self;
}

- (BOOL)needToUpload {
    BOOL needToUpload = false;
    switch (self.state) {
        case QNUploadStateNeedToCheck:
        case QNUploadStateWaitToUpload:
            needToUpload = true;
            break;
        default:
            break;
    }
    return needToUpload;
}

- (BOOL)isUploaded {
    return self.state == QNUploadStateComplete;
}

- (void)setState:(QNUploadState)state {
    switch (self.state) {
        case QNUploadStateNeedToCheck:
        case QNUploadStateWaitToUpload:
        case QNUploadStateUploading:
            self.uploadSize = 0;
            self.etag = @"";
            break;
        default:
            self.data = nil;
            break;
    }
    _state = state;
}

- (long long)uploadSize {
    if (self.state == QNUploadStateComplete) {
        return _size;
    } else {
        return _uploadSize;
    }
}

- (void)clearUploadState{
    self.state = QNUploadStateNeedToCheck;
    self.etag = nil;
    self.md5 = nil;
}

- (void)checkStateAndUpdate {
    if ((self.state == QNUploadStateWaitToUpload || self.state == QNUploadStateUploading) && self.data == nil) {
        self.state = QNUploadStateNeedToCheck;
    }
}

- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"offset"] = @(self.offset);
    dictionary[@"size"]   = @(self.size);
    dictionary[@"index"]  = @(self.index);
    dictionary[@"etag"]   = self.etag ?: @"";
    dictionary[@"md5"]    = self.md5 ?: @"";
    dictionary[@"state"]  = @(self.state);
    return [dictionary copy];
}

@end

