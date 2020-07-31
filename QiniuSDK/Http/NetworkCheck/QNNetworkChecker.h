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

@property(nonatomic, weak)id <QNNetworkCheckerDelegate> delegate;

+ (instancetype)networkChecker;

- (BOOL)checkIP:(NSString *)ip host:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
