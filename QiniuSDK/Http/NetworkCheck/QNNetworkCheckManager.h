//
//  QNNetworkCheckManager.h
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNTransactionManager.h"

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

// 是否开启网络检测
@property(nonatomic, assign)BOOL isCheckOpen;

// 单个IP一次检测次数 默认：2次
@property(nonatomic, assign)int maxCheckCount;
// 单个IP检测的最长时间 maxTime >= 1 && maxTime <= 600  默认：9秒
@property(nonatomic, assign)int maxTime;

+ (instancetype)shared;

- (QNNetworkCheckStatus)getIPNetworkStatus:(NSString *)ip
                                      host:(NSString *)host;

@end

@interface QNTransactionManager(NetworkCheck)

/// 查询IP列表中IP的网络状态
/// 结果会被缓存，可以通过QNNetworkCheckManager -> getIPNetworkStatus:host:查询某个IP的网络状态
/// @param ipArray host Dns解析后的IP列表
/// @param host IP对用的Host,
- (void)addCheckSomeIPNetworkStatusTransaction:(NSArray <NSString *> *)ipArray
                                          host:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
