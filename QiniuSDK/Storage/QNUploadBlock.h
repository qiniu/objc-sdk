//
//  QNUploadBlock.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadData.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadBlock : NSObject
// block下标
@property(nonatomic, assign, readonly)NSInteger index;
// 当前data偏移量
@property(nonatomic, assign, readonly)long long offset;
// 块大小
@property(nonatomic, assign, readonly)NSInteger size;
// 需要上传的片数据
@property(nonatomic, strong, readonly)NSArray <QNUploadData *> *uploadDataList;
// block上传上下文信息
@property(nonatomic,   copy, nullable)NSString *context;
// block md5
@property(nonatomic,   copy, nullable)NSString *md5;
// 是否已完成上传【不进行离线缓存】
@property(nonatomic, assign, readonly)BOOL isCompleted;
// 上传大小 【不进行离线缓存】
@property(nonatomic, assign, readonly)NSInteger uploadSize;

//MARK:-- 构造
+ (instancetype)blockFromDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithOffset:(long long)offset
                     blockSize:(NSInteger)blockSize
                      dataSize:(NSInteger)dataSize
                         index:(NSInteger)index;

/// 获取下一个需要上传的块
- (QNUploadData *)nextUploadDataWithoutCheckData;

/// 检测 data 状态，处理出于上传状态的无 data 数据的情况，无 data 数据则状态调整为监测数据状态
- (void)checkInfoStateAndUpdate;

/// 清理上传状态
- (void)clearUploadState;

/// 转化字典
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
