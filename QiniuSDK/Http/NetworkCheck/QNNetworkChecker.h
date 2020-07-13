//
//  QNNetworkChecker.h
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNNetworkCheckerDelegate <NSObject>

/// 检测完成
/// @param ip 检测的ip
/// @param host ip对应的host
/// @param time 链接建立所用时间，单位:毫秒
- (void)checkComplete:(NSString *)ip host:(NSString *)host time:(long)time;

@end
@interface QNNetworkChecker : NSObject

// 单个IP一次检测次数 默认：2次
@property(nonatomic, assign)int maxCheckCount;
// 单个IP检测的最长时间 maxTime >= 1 && maxTime <= 600  默认：9秒
@property(nonatomic, assign)int maxTime;

@property(nonatomic, weak)id <QNNetworkCheckerDelegate> delegate;

+ (instancetype)networkChecker;

- (BOOL)checkIP:(NSString *)ip host:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
