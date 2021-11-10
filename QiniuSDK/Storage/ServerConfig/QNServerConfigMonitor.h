//
//  QNServerConfiguration.h
//  QiniuSDK
//
//  Created by yangsen on 2021/8/25.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNServerConfigMonitor : NSObject

@property(nonatomic, assign, class)BOOL enable;

@property(class, nonatomic, strong)NSString *token;

// 开始监控
+ (void)startMonitor;

// 停止监控
+ (void)endMonitor;

// 配置 token
+ (void)setToken:(NSString *)token;

// 移除缓存
+ (void)removeConfigCache;

@end

NS_ASSUME_NONNULL_END
