//
//  QNUploadFileInfoPartV1.h
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadFileInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadBlock : NSObject
// block下标
@property(nonatomic, assign, readonly)NSInteger index;
// 当前data偏移量
@property(nonatomic, assign, readonly)long long offset;
// 块大小
@property(nonatomic, assign, readonly)long long size;
// 需要上传的片数据
@property(nonatomic, strong, readonly)NSArray <QNUploadData *> *uploadDataList;
// block上传上下文信息
@property(nonatomic,  copy)NSString *context;
// 是否已完成上传【不进行离线缓存】
@property(nonatomic, assign, readonly)BOOL isCompleted;
// 上传进度 【不进行离线缓存】
@property(nonatomic, assign, readonly)float progress;

//MARK:-- 构造
+ (instancetype)blockFromDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithOffset:(long long)offset
                     blockSize:(NSInteger)blockSize
                      dataSize:(NSInteger)dataSize
                         index:(NSInteger)index;

/// 获取下一个需要上传的块
- (QNUploadData *)nextUploadData;

/// 转化字典
- (NSDictionary *)toDictionary;

@end


@interface QNUploadFileInfoPartV1 : QNUploadFileInfo

// 需要上传的块
@property(nonatomic, strong, readonly)NSArray <QNUploadBlock *> *uploadBlocks;

- (instancetype)initWithFileSize:(long long)fileSize
                       blockSize:(long long)blockSize
                        dataSize:(long long)dataSize
                      modifyTime:(NSInteger)modifyTime;

/// 获取下一个需要上传的chunk所在的block
- (QNUploadBlock *)nextUploadBlock;

/// 获取所有block context
- (NSArray <NSString *> *)allBlocksContexts;

@end

NS_ASSUME_NONNULL_END
