//
//  QNUploadFileInfoPartV2.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadFileInfoPartV2.h"

@interface QNUploadFileInfoPartV2()

@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger modifyTime;
@property(nonatomic, strong)NSArray <QNUploadData *> *uploadDataList;

@end
@implementation QNUploadFileInfoPartV2

@synthesize size = _size;
@synthesize modifyTime = _modifyTime;
@synthesize uploadDataList = _uploadDataList;

+ (instancetype)infoFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    QNUploadFileInfoPartV2 *fileInfo = [[QNUploadFileInfoPartV2 alloc] init];
    fileInfo.size = [dictionary[@"size"] longLongValue];
    fileInfo.modifyTime = [dictionary[@"modifyTime"] integerValue];
    fileInfo.expireAt = dictionary[@"expireAt"];
    fileInfo.uploadId = dictionary[@"uploadId"];
    
    NSArray *uploadDataList = dictionary[@"uploadDataList"];
    if ([uploadDataList isKindOfClass:[NSArray class]]) {
        
        NSMutableArray *uploadDataObjectList = [NSMutableArray array];
        for (NSDictionary *uploadDataInfo in uploadDataList) {
            
            QNUploadData *data = [QNUploadData dataFromDictionary:uploadDataInfo];
            if (data) {
                [uploadDataObjectList addObject:data];
            }
        }
        fileInfo.uploadDataList = [uploadDataObjectList copy];
    }
    return fileInfo;
}

- (instancetype)initWithFileSize:(long long)fileSize
                        dataSize:(long long)dataSize
                      modifyTime:(NSInteger)modifyTime{
    if (self = [super init]) {
        _size = fileSize;
        _modifyTime = modifyTime;
        [self createDataList:dataSize];
    }
    return self;
}

- (void)createDataList:(long long)dataSize{
    
    long long offSize = 0;
    NSInteger dataIndex = 1;
    NSMutableArray *datas = [NSMutableArray array];
    while (offSize < self.size) {
        long long lastSize = self.size - offSize;
        long long dataSizeP = MIN(lastSize, dataSize);
        QNUploadData *data = [[QNUploadData alloc] initWithOffset:offSize
                                                         dataSize:dataSizeP
                                                            index:dataIndex];
        [datas addObject:data];
        offSize += dataSizeP;
        dataIndex += 1;
    }
    self.uploadDataList = [datas copy];
}

//- (void)resetDataSize:(long long)dataSize{
//    if (!self.uploadDataList || self.uploadDataList.count == 0) {
//        [self createDataSize:dataSize];
//        return;
//    }
//
//    for (QNUploadData *data in self.uploadDataList) {
//        if (!data.isCompleted && !data.isUploading) {
//            data.size = dataSize;
//        }
//    }
//}

- (QNUploadData *)nextUploadData{
    if (!self.uploadDataList || self.uploadDataList.count == 0) {
        return nil;
    }
    
    QNUploadData *data = nil;
    for (QNUploadData *dataP in self.uploadDataList) {
        if (!dataP.isCompleted && !dataP.isUploading) {
            data = dataP;
            break;
        }
    }
    return data;
}

- (void)clearUploadState{
    for (QNUploadData *data in self.uploadDataList) {
        [data clearUploadState];
    }
    self.uploadId = nil;
    self.expireAt = nil;
}

- (BOOL)isAllUploaded{
    BOOL isCompleted = YES;
    for (QNUploadData *data in self.uploadDataList) {
        if (data.isCompleted == NO) {
            isCompleted = NO;
            break;
        }
    }
    return isCompleted;
}

- (float)progress{
    float progress = 0;
    for (QNUploadData *data in self.uploadDataList) {
        progress += data.progress * ((float)data.size / (float)self.size);
    }
    return progress;
}

- (NSArray <NSDictionary *> *)getPartInfoArray{
    if (!self.uploadId || self.uploadId.length == 0) {
        return nil;
    }
    NSArray *uploadDataList = [self.uploadDataList sortedArrayUsingComparator:^NSComparisonResult(QNUploadData * _Nonnull obj1, QNUploadData * _Nonnull obj2) {
        return obj1.index - obj2.index;
    }];
    NSMutableArray *infoArray = [NSMutableArray array];
    for (QNUploadData *data in uploadDataList) {
        if (data.etag) {
            [infoArray addObject:@{@"etag" : data.etag, @"partNumber" : @(data.index)}];
        } else {
            infoArray = nil;
            break;
        }
    }
    return [infoArray copy];
}

- (NSDictionary *)toDictionary{
    if (!self.expireAt || !self.uploadId) {
        return nil;
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"size"] = @(self.size);
    dictionary[@"modifyTime"] = @(self.modifyTime);
    dictionary[@"expireAt"] = self.expireAt;
    dictionary[@"uploadId"] = self.uploadId;

    if (self.uploadDataList) {
        
        NSMutableArray *uploadDataInfos = [NSMutableArray array];
        for (QNUploadData *data in self.uploadDataList) {
            
            NSDictionary *uploadDataInfo = [data toDictionary];
            if (uploadDataInfo) {
                [uploadDataInfos addObject:uploadDataInfo];
            }
        }
        dictionary[@"uploadDataList"]  = [uploadDataInfos copy];
    }
    
    return [dictionary copy];
}

@end
