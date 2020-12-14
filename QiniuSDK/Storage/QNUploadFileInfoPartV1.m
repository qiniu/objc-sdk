//
//  QNUploadFileInfoPartV1.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadFileInfoPartV1.h"

@interface QNUploadBlock()

@property(nonatomic, assign)long long offset;
@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger index;
@property(nonatomic, strong)NSArray <QNUploadData *> *uploadDataList;

@end
@implementation QNUploadBlock

+ (instancetype)blockFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
         
    QNUploadBlock *block = [[QNUploadBlock alloc] init];
    block.offset = [dictionary[@"offset"] longLongValue];
    block.size = [dictionary[@"size"] longLongValue];
    block.index = [dictionary[@"index"] integerValue];
    block.context = dictionary[@"context"];
    
    NSArray *uploadDataInfos = dictionary[@"uploadDataList"];
    if ([uploadDataInfos isKindOfClass:[NSArray class]]) {
        
        NSMutableArray *uploadDataList = [NSMutableArray array];
        for (NSDictionary *uploadDataInfo in uploadDataInfos) {
            
            QNUploadData *data = [QNUploadData dataFromDictionary:uploadDataInfo];
            if (data) {
                [uploadDataList addObject:data];
            }
        }
        block.uploadDataList = [uploadDataList copy];
    }
    return block;
}

- (instancetype)initWithOffset:(long long)offset
                     blockSize:(NSInteger)blockSize
                      dataSize:(NSInteger)dataSize
                         index:(NSInteger)index {
    if (self = [super init]) {
        _offset = offset;
        _size = blockSize;
        _index = index;
        [self createDataList:dataSize];
    }
    return self;
}

- (BOOL)isCompleted{
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

- (void)createDataList:(long long)dataSize{
    
    long long offSize = 0;
    NSInteger dataIndex = 1; /// 从1开始 兼容分片v2
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
}

- (NSDictionary *)toDictionary{
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"offset"] = @(self.offset);
    dictionary[@"size"]   = @(self.size);
    dictionary[@"index"]  = @(self.index);
    if (self.context) {
        dictionary[@"context"] = self.context;
    }

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


@interface QNUploadFileInfoPartV1()

@property(nonatomic, assign)long long size;
@property(nonatomic, assign)NSInteger modifyTime;
@property(nonatomic, strong)NSArray <QNUploadBlock *> *uploadBlocks;

@end

@implementation QNUploadFileInfoPartV1

@synthesize size = _size;
@synthesize modifyTime = _modifyTime;

+ (instancetype)infoFromDictionary:(NSDictionary *)dictionary{
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    QNUploadFileInfoPartV1 *fileInfo = [[QNUploadFileInfoPartV1 alloc] init];
    fileInfo.size = [dictionary[@"size"] longLongValue];
    fileInfo.modifyTime = [dictionary[@"modifyTime"] integerValue];
    
    NSArray *uploadBlocksInfos = dictionary[@"uploadBlocks"];
    if ([uploadBlocksInfos isKindOfClass:[NSArray class]]) {
        
        NSMutableArray *uploadBlocks = [NSMutableArray array];
        for (NSDictionary *uploadBlock in uploadBlocksInfos) {
            
            QNUploadBlock *block = [QNUploadBlock blockFromDictionary:uploadBlock];
            if (block) {
                [uploadBlocks addObject:block];
            }
        }
        fileInfo.uploadBlocks = [uploadBlocks copy];
    }
    return fileInfo;
}

- (instancetype)initWithFileSize:(long long)fileSize
                       blockSize:(long long)blockSize
                        dataSize:(long long)dataSize
                      modifyTime:(NSInteger)modifyTime{
    if (self = [super init]) {
        _size = fileSize;
        _modifyTime = modifyTime;
        [self createBlocks:blockSize dataSize:dataSize];
    }
    return self;
}

- (void)createBlocks:(long long)blockSize dataSize:(long long)dataSize{
    
    long long offSize = 0;
    NSInteger blockIndex = 0;
    NSMutableArray *blocks = [NSMutableArray array];
    while (offSize < self.size) {
        long long lastSize = self.size - offSize;
        long long blockSizeP = MIN(lastSize, blockSize);
        QNUploadBlock *block = [[QNUploadBlock alloc] initWithOffset:offSize
                                                           blockSize:blockSizeP
                                                            dataSize:dataSize
                                                               index:blockIndex];
        [blocks addObject:block];
        offSize += blockSizeP;
        blockIndex += 1;
    }
    self.uploadBlocks = [blocks copy];
}

- (QNUploadBlock *)nextUploadBlock{
    if (!self.uploadBlocks || self.uploadBlocks.count == 0) {
        return nil;
    }
    
    QNUploadBlock *block = nil;
    for (QNUploadBlock *blockP in self.uploadBlocks) {
        if ([blockP nextUploadData]) {
            block = blockP;
            break;
        }
    }
    return block;
}

- (void)clearUploadState{
    for (QNUploadBlock *block in self.uploadBlocks) {
        [block clearUploadState];
    }
}

- (BOOL)isAllUploaded{
    BOOL isAllUploaded = YES;
    for (QNUploadBlock *block in self.uploadBlocks) {
        if (!block.isCompleted) {
            isAllUploaded = NO;
            break;
        }
    }
    return isAllUploaded;
}

- (float)progress{
    float progress = 0;
    for (QNUploadBlock *block in self.uploadBlocks) {
        progress += block.progress * ((float)block.size / (float)self.size);
    }
    return progress;
}

- (BOOL)isEmpty{
    return !self.uploadBlocks || self.uploadBlocks.count == 0;
}

- (NSArray <NSString *> *)allBlocksContexts{
    if (!self.uploadBlocks || self.uploadBlocks.count == 0) {
        return nil;
    }
    
    NSMutableArray *contexts = [NSMutableArray array];
    for (QNUploadBlock *block in self.uploadBlocks) {
        if (block.context) {
            [contexts addObject:block.context];
        }
    }
    
    return [contexts copy];
}

- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"size"] = @(self.size);
    dictionary[@"modifyTime"] = @(self.modifyTime);
    
    if (self.uploadBlocks) {
        
        NSMutableArray *uploadBlockInfos = [NSMutableArray array];
        for (QNUploadBlock *block in self.uploadBlocks) {
            
            NSDictionary *uploadBlockInfo = [block toDictionary];
            if (uploadBlockInfo) {
                [uploadBlockInfos addObject:uploadBlockInfo];
            }
        }
        dictionary[@"uploadBlocks"]  = [uploadBlockInfos copy];
    }
    
    return [dictionary copy];
}

@end
