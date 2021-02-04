//
//  QNNetworkStatusManager.h
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNNetworkStatus : NSObject

/// 网速 单位：kb/s   默认：200kb/s
@property(nonatomic, assign, readonly)int speed;

@end


#define kQNNetworkStatusManager [QNNetworkStatusManager sharedInstance]
@interface QNNetworkStatusManager : NSObject


+ (instancetype)sharedInstance;

- (QNNetworkStatus *)getNetworkStatus:(NSString *)type;

- (void)updateNetworkStatus:(NSString *)type
                      speed:(int)speed;

@end

NS_ASSUME_NONNULL_END
