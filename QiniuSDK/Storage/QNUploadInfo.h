//
//  QNUploadInfo.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadInfo : NSObject

/// 构造函数
/// @param source 上传数据源
+ (instancetype)info:(id <QNUploadSource>)source;

/// 通过字典信息进行配置
/// @param dictionary 配置信息
- (void)setInfoFromDictionary:(NSDictionary *)dictionary;

/// 信息转化为字典
- (NSDictionary *)toDictionary;

/// 数据源是否有效，为空则无效
- (BOOL)hasValidResource;

/// 是否有效，数据源是否有效 & 上传信息有效，比如断点续传时，UploadId是否有效
- (BOOL)isValid;

/// 是否可以重新
- (BOOL)couldReloadSource;

/// 重新加载数据
- (BOOL)reloadSource;

/// 数据源ID
- (NSString *)getSourceId;

/// 数据源大小，未知为：-1
- (long long)getSourceSize;

/// 是否为同一个 UploadInfo，
/// 同一个：source 相同，上传方式相同
/// @param info 上传信息
- (BOOL)isSameUploadInfo:(QNUploadInfo *)info;

/// 已上传大小
- (long long)uploadSize;

/// 资源是否已全部上传
/// 子类重写
- (BOOL)isAllUploaded;

/// 清除上传状态信息
/// 子类重写
- (void)clearUploadState;

/// 检查文件状态, 主要处理没有 data 但处于上传状态
- (void)checkInfoStateAndUpdate;

/// 读取数据
/// @param dataSize 读取数据大小
/// @param dataOffset 数据偏移量
/// @param error 读取时的错误信息
- (NSData *)readData:(NSInteger)dataSize dataOffset:(long long)dataOffset error:(NSError **)error;

/// 关闭流
- (void)close;

@end

#define kQNUploadInfoTypeKey @"infoType"
NS_ASSUME_NONNULL_END
