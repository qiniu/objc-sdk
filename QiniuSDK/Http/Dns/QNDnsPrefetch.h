//
//  QNDnsPrefetch.h
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNDns.h"
#import "QNUpToken.h"
#import "QNConfiguration.h"
#import "QNTransactionManager.h"

NS_ASSUME_NONNULL_BEGIN

#define kQNDnsPrefetch [QNDnsPrefetch shared]
@interface QNDnsPrefetch : NSObject

/// 最近一次预取错误信息
@property(nonatomic,  copy, readonly)NSString *lastPrefetchedErrorMessage;

+ (instancetype)shared;

/// 无效缓存，会根据inetAddress的host获取缓存列表，并移除inetAddress
/// @param inetAddress address 信息
- (void)invalidInetAdress:(id <QNIDnsNetworkAddress>)inetAddress;

/// 根据host从缓存中读取DNS信息
/// @param host 域名
- (NSArray <id <QNIDnsNetworkAddress> > *)getInetAddressByHost:(NSString *)host;

@end



@interface QNTransactionManager(Dns)

/// 添加加载本地dns事务
- (void)addDnsLocalLoadTransaction;

/// 添加检测并预取dns事务 如果未开启DNS 或 事务队列中存在token对应的事务未处理，则返回NO
/// @param currentZone 当前区域
/// @param token token信息
- (BOOL)addDnsCheckAndPrefetchTransaction:(QNZone *)currentZone token:(QNUpToken *)token;

/// 设置定时事务：检测已缓存DNS有效情况事务 无效会重新预取
- (void)setDnsCheckWhetherCachedValidTransactionAction;

@end

NS_ASSUME_NONNULL_END
