//
//  QNUploadInfoV2.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/13.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "NSData+QNMD5.h"
#import "QNUploadInfoV2.h"

#define kTypeValue @"UploadInfoV2"
#define kMaxDataSize (1024 * 1024 * 1024)

@interface QNUploadInfoV2()

@property(nonatomic, assign)int dataSize;
@property(nonatomic, strong)NSMutableArray <QNUploadData *> *dataList;

@property(nonatomic, assign)BOOL isEOF;
@property(nonatomic, strong, nullable)NSError *readError;
@end
@implementation QNUploadInfoV2

+ (instancetype)info:(id<QNUploadSource>)source
       configuration:(nonnull QNConfiguration *)configuration {
    
    QNUploadInfoV2 *info = [QNUploadInfoV2 info:source];
    info.dataSize = MIN(configuration.chunkSize, kMaxDataSize);
    info.dataList = [NSMutableArray array];
    return info;
}

+ (instancetype)info:(id <QNUploadSource>)source
          dictionary:(NSDictionary *)dictionary {
    if (dictionary == nil) {
        return nil;
    }
    
    int dataSize = [dictionary[@"dataSize"] intValue];
    NSNumber *expireAt = dictionary[@"expireAt"];
    NSString *uploadId = dictionary[@"uploadId"];
    NSString *type = dictionary[kQNUploadInfoTypeKey];
    if (expireAt == nil || ![expireAt isKindOfClass:[NSNumber class]] ||
        uploadId == nil || ![uploadId isKindOfClass:[NSString class]] || uploadId.length == 0) {
        return nil;
    }
    
    NSArray *dataInfoList = dictionary[@"dataList"];
    
    NSMutableArray <QNUploadData *> *dataList = [NSMutableArray array];
    if ([dataInfoList isKindOfClass:[NSArray class]]) {
        for (int i = 0; i < dataInfoList.count; i++) {
            NSDictionary *dataInfo = dataInfoList[i];
            if ([dataInfo isKindOfClass:[NSDictionary class]]) {
                QNUploadData *data = [QNUploadData dataFromDictionary:dataInfo];
                if (data == nil) {
                    return nil;
                }
                [dataList addObject:data];
            }
        }
    }
    
    QNUploadInfoV2 *info = [QNUploadInfoV2 info:source];
    [info setInfoFromDictionary:dictionary];
    info.expireAt = expireAt;
    info.uploadId = uploadId;
    info.dataSize = dataSize;
    info.dataList = dataList;
    
    if (![type isEqualToString:kTypeValue] || ![[source getId] isEqualToString:[info getSourceId]]) {
        return nil;
    } else {
        return info;
    }
}

- (BOOL)isValid {
    if (![super isValid]) {
        return false;
    }
    
    if (!self.expireAt || !self.uploadId || self.uploadId.length == 0) {
        return false;
    }
    
    return self.expireAt.doubleValue > [[NSDate date] timeIntervalSince1970] - 24*3600;
}

- (BOOL)reloadSource {
    self.isEOF = false;
    self.readError = nil;
    return [super reloadSource];
}

- (BOOL)isSameUploadInfo:(QNUploadInfo *)info {
    if (![super isSameUploadInfo:info]) {
        return false;
    }
    
    if (![info isKindOfClass:[QNUploadInfoV2 class]]) {
        return false;
    }
    
    return self.dataSize == [(QNUploadInfoV2 *)info dataSize];
}

- (void)clearUploadState {
    if (self.dataList == nil || self.dataList.count == 0) {
        return;
    }
    
    for (QNUploadData *data in self.dataList) {
        [data clearUploadState];
    }
}

- (void)checkInfoStateAndUpdate {
    for (QNUploadData *data in self.dataList) {
        [data checkStateAndUpdate];
    }
}

- (long long)uploadSize {
    if (self.dataList == nil || self.dataList.count == 0) {
        return 0;
    }
    
    long long uploadSize = 0;
    for (QNUploadData *data in self.dataList) {
        uploadSize += [data uploadSize];
    }
    return uploadSize;
}

- (BOOL)isAllUploaded {
    if (!_isEOF) {
        return false;
    }
    
    if (self.dataList == nil || self.dataList.count == 0) {
        return true;
    }
    
    BOOL isAllUploaded = true;
    for (QNUploadData *data in self.dataList) {
        if (!data.isUploaded) {
            isAllUploaded = false;
            break;
        }
    }
    return isAllUploaded;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dictionary = [[super toDictionary] mutableCopy];
    if (dictionary == nil) {
        dictionary = [NSMutableDictionary dictionary];
    }
    [dictionary setObject:kTypeValue forKey:kQNUploadInfoTypeKey];
    [dictionary setObject:@(self.dataSize) forKey:@"dataSize"];
    [dictionary setObject:self.expireAt ?: 0 forKey:@"expireAt"];
    [dictionary setObject:self.uploadId ?: @"" forKey:@"uploadId"];
    
    if (self.dataList != nil && self.dataList.count != 0) {
        NSMutableArray *blockInfoList = [NSMutableArray array];
        for (QNUploadData *data in self.dataList) {
            [blockInfoList addObject:[data toDictionary]];
        }
        [dictionary setObject:[blockInfoList copy] forKey:@"dataList"];
    }
    
    return [dictionary copy];
}

- (NSInteger)getPartIndexOfData:(QNUploadData *)data {
    return data.index + 1;
}

- (QNUploadData *)nextUploadData:(NSError **)error {
    
    // 从 dataList 中读取需要上传的 data
    QNUploadData *data = [self nextUploadDataFormDataList];
    
    // 内存的 dataList 中没有可上传的数据，则从资源中读并创建 data
    if (data == nil) {
        if (self.isEOF) {
            return nil;
        } else if (self.readError) {
            *error = self.readError;
            return nil;
        }
        
        // 从资源中读取新的 block 进行上传
        long dataOffset = 0;
        if (self.dataList.count > 0) {
            QNUploadData *lastData = self.dataList[self.dataList.count - 1];
            dataOffset = lastData.offset + lastData.size;
        }
        
        data = [[QNUploadData alloc] initWithOffset:dataOffset dataSize:self.dataSize index:self.dataList.count];
    }
    
    QNUploadData*loadData = [self loadData:data error:error];
    if (*error != nil) {
        self.readError = *error;
        return nil;
    }
    
    if (loadData == nil) {
        // 没有加在到 data, 也即数据源读取结束
        self.isEOF = true;
        // 有多余的 data 则移除，移除中包含 data
        if (self.dataList.count > data.index) {
            self.dataList = [[self.dataList subarrayWithRange:NSMakeRange(0, data.index)] mutableCopy];
        }
    } else {
        // 加在到 data
        if (loadData.index == self.dataList.count) {
            // 新块：data index 等于 dataList size 则为新创建 block，需要加入 dataList
            [self.dataList addObject:loadData];
        } else if (loadData != data) {
            // 更换块：重新加在了 data， 更换信息
            [self.dataList replaceObjectAtIndex:loadData.index withObject:loadData];
        }
        
        // 数据源读取结束，块读取大小小于预期，读取结束
        if (loadData.size < data.size) {
            self.isEOF = true;
            // 有多余的 data 则移除，移除中不包含 data
            if (self.dataList.count > data.index + 1) {
                self.dataList = [[self.dataList subarrayWithRange:NSMakeRange(0, data.index + 1)] mutableCopy];
            }
        }
    }
    
    return loadData;
}

- (QNUploadData *)nextUploadDataFormDataList {
    if (self.dataList == nil || self.dataList.count == 0) {
        return nil;
    }
    
    QNUploadData *data = nil;
    for (QNUploadData *dataP in self.dataList) {
        if ([data needToUpload]) {
            data = dataP;
            break;
        }
    }
    
    return data;
}

// 加载块中的数据
// 1. 数据块已加载，直接返回
// 2. 数据块未加载，读块数据
// 2.1 如果未读到数据，则已 EOF，返回 null
// 2.2 如果读到数据
// 2.2.1 如果块数据符合预期，则当片未上传，则加载片数据
// 2.2.2 如果块数据不符合预期，创建新块，加载片信息
- (QNUploadData *)loadData:(QNUploadData *)data error:(NSError **)error {
    if (data == nil) {
        return nil;
    }
    
    // 之前已加载并验证过数据，不必在验证
    if (data.data != nil) {
        return data;
    }
    
    // 未加载过 block 数据
    // 根据 data 信息加载 dataBytes
    NSData *dataBytes = [self readData:data.size dataOffset:data.offset error:error];
    if (*error != nil) {
        return nil;
    }

    // 没有数据不需要上传
    if (dataBytes == nil || dataBytes.length == 0) {
        return nil;
    }

    NSString *md5 = [dataBytes qn_md5];
    // 判断当前 block 的数据是否和实际数据吻合，不吻合则之前 block 被抛弃，重新创建 block
    if (dataBytes.length != data.size || data.md5 == nil || ![data.md5 isEqualToString:md5]) {
        data = [[QNUploadData alloc] initWithOffset:data.offset dataSize:self.dataSize index:data.index];
        data.md5 = md5;
    }

    if (data.etag == nil || data.etag.length == 0) {
        data.data = dataBytes;
        data.state = QNUploadStateWaitToUpload;
    } else {
        data.state = QNUploadStateComplete;
    }

    return data;
}

- (NSArray <NSDictionary <NSString *, NSObject *> *> *)getPartInfoArray {
    if (self.uploadId == nil || self.uploadId.length == 0) {
        return nil;
    }
    
    NSMutableArray *infoArray = [NSMutableArray array];
    for (QNUploadData *data in self.dataList) {
        if (data.state == QNUploadStateComplete && data.etag != nil) {
            [infoArray addObject:@{@"etag" : data.etag,
                                   @"partNumber" : @([self getPartIndexOfData:data])}];
        }
    }
    
    return [infoArray copy];
}

@end
