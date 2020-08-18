//
//  QNUtils.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/3/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUtils : NSObject

/// SDK 名称
+ (NSString *)sdkVersion;

/// SDK 开发语言
+ (NSString *)sdkLanguage;

/// 获取当前进程ID
+ (int64_t)getCurrentProcessID;

/// 获取当前线程ID
+ (int64_t)getCurrentThreadID;

/// 系统名称
+ (NSString *)systemName;

/// 系统版本
+ (NSString *)systemVersion;

/// 信号格数
+ (NSNumber *)getCurrentSignalStrength;

/// 网络类型
+ (NSString *)getCurrentNetworkType;

/// 获取当前时间戳 单位：ms
+ (NSTimeInterval)currentTimestamp;

/// sdk document文件路径
+ (NSString *)sdkDocumentDirectory;

/// sdk cache文件路径
+ (NSString *)sdkCacheDirectory;

/// form escape
/// @param string escape string
+ (NSString *)formEscape:(NSString *)string;

/// 根据ip和host来确定IP的类型，host可为空
/// @param ip ip
/// @param host host
+ (NSString *)getIpType:(NSString *)ip host:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
