//
//  QNNetworkCheckManager.h
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QNNetworkCheckStatus) {
    QNNetworkCheckStatusUnknown,
    QNNetworkCheckStatusA,
    QNNetworkCheckStatusB,
    QNNetworkCheckStatusC,
    QNNetworkCheckStatusD,
};

#define kQNNetworkCheckManager [QNNetworkCheckManager shared]
@interface QNNetworkCheckManager : NSObject

// 单个IP一次检测次数 默认：2次
@property(nonatomic, assign)int maxCheckCount;

+ (instancetype)shared;

- (QNNetworkCheckStatus)getIPNetworkStatus:(NSString *)ip
                                      host:(NSString *)host;

- (void)preCheckIPNetworkStatus:(NSArray <NSString *> *)ipArray
                           host:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
