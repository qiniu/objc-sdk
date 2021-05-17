//
//  QNUploadData.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, QNUploadState) {
    QNUploadStateNeedToCheck, // 需要检测数据
    QNUploadStateWaitToUpload, // 等待上传
    QNUploadStateUploading, // 正在上传
    QNUploadStateComplete, // 上传结束
};

@interface QNUploadData : NSObject

/// 当前data偏移量
@property(nonatomic, assign, readonly)long long offset;
/// 当前data大小
@property(nonatomic, assign, readonly)long long size;
/// data下标
@property(nonatomic, assign, readonly)NSInteger index;
/// data etag
@property(nonatomic, copy, nullable)NSString *etag;
/// data md5
@property(nonatomic, copy, nullable)NSString *md5;
/// 上传状态
@property(nonatomic, assign)QNUploadState state;
/// 上传进度 【不进行离线缓存】
@property(nonatomic, assign)long long uploadSize;
/// 上传数据 【不进行离线缓存】
@property(nonatomic, strong, nullable)NSData *data;

//MARK:-- 构造
+ (instancetype)dataFromDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithOffset:(long long)offset
                      dataSize:(long long)dataSize
                         index:(NSInteger)index;

//MARK:-- logic
/// 是否需要上传
- (BOOL)needToUpload;
/// 是否已经上传
- (BOOL)isUploaded;

/// 检测 data 状态，处理出于上传状态的无 data 数据的情况，无 data 数据则状态调整为监测数据状态
- (void)checkStateAndUpdate;

/// 转化字典
- (NSDictionary *)toDictionary;
/// 清除状态
- (void)clearUploadState;

@end

NS_ASSUME_NONNULL_END
