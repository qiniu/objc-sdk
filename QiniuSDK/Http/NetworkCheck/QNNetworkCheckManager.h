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
    QNNetworkCheckStatusA,
    QNNetworkCheckStatusB,
    QNNetworkCheckStatusC,
    QNNetworkCheckStatusD,
    QNNetworkCheckStatusUnknown,
};

#define kQNNetworkCheckManager [QNNetworkCheckManager shared]
@interface QNNetworkCheckManager : NSObject

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
