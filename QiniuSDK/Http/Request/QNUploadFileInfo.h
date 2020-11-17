//
//  QNUploadData.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadData : NSObject

/// 当前data偏移量
@property(nonatomic, assign, readonly)long long offset;
/// 当前data大小
@property(nonatomic, assign, readonly)long long size;
/// data下标
@property(nonatomic, assign, readonly)NSInteger index;
/// data etag
@property(nonatomic, copy)NSString *etag;
/// 是否已完成上传
@property(atomic, assign)BOOL isCompleted;
/// 是否正在上传 【不进行离线缓存】
@property(atomic, assign)BOOL isUploading;
/// 上传进度 【不进行离线缓存】
@property(nonatomic, assign)float progress;

//MARK:-- 构造
+ (instancetype)dataFromDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithOffset:(long long)offset
                      dataSize:(long long)dataSize
                         index:(NSInteger)index;

//MARK:-- logic
- (BOOL)isFirstData;
/// 转化字典
- (NSDictionary *)toDictionary;

@end


@interface QNUploadFileInfo : NSObject

// 文件大小
@property(nonatomic, assign, readonly)long long size;
// 文件修改时间
@property(nonatomic, assign, readonly)NSInteger modifyTime;
// 需要上传的块
@property(nonatomic, strong, readonly)NSArray <QNUploadData *> *uploadDataList;
// 上传进度 【不进行离线缓存】
@property(nonatomic, assign, readonly)float progress;
// 上传标识符
@property(nonatomic,   copy)NSString *uploadId;
// 上传标识符有效期
@property(nonatomic, strong)NSNumber *expireAt;

//MARK:-- 构造

+ (instancetype)infoFromDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithFileSize:(long long)fileSize
                        dataSize:(long long)dataSize
                      modifyTime:(NSInteger)modifyTime;

//MARK:-- logic

/// 获取下一个需要上传的块
- (QNUploadData *)nextUploadData;

/// 清除所有块和分片上传状态信息
- (void)clearUploadState;

/// [{ "etag": "<Etag>", "partNumber": <PartNumber> }, ...],
- (NSArray <NSDictionary *> *)getPartInfoArray;

/// 所有的块是否都已经上传完毕
- (BOOL)isAllUploaded;

/// 获取所有block context
- (NSArray <NSString *> *)allBlocksContexts;

/// 转化字典
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
