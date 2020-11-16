//
//  QNTransactionManager.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNTransaction : NSObject

/// 事务名称
@property(nonatomic,   copy, readonly)NSString *name;
/// 事务延迟执行时间 单位：秒
@property(nonatomic, assign, readonly)NSInteger after;
/// 事务内容
@property(nonatomic,   copy, readonly)void(^action)(void);

/// MARK: -- 构造方法
/// 普通事务，事务体仅仅执行一次
/// @param name 事务名称
/// @param after  事务延后时间 单位：秒
/// @param action 事务体
+ (instancetype)transaction:(NSString *)name
                      after:(NSInteger)after
                     action:(void(^)(void))action;
/// 定时事务
/// @param name 事务名称
/// @param after 事务延后时间 单位：秒
/// @param interval 事务执行间隔 单位：秒
/// @param action 事务体
+ (instancetype)timeTransaction:(NSString *)name
                          after:(NSInteger)after
                       interval:(NSInteger)interval
                         action:(void(^)(void))action;

@end


#define kQNTransactionManager [QNTransactionManager shared]
@interface QNTransactionManager : NSObject

/// 单例构造方法
+ (instancetype)shared;

/// 根据name查找事务
/// @param name 事务名称
- (NSArray <QNTransaction *> *)transactionsForName:(NSString *)name;

/// 是否存在某个名称的事务
/// @param name 事务名称
- (BOOL)existTransactionsForName:(NSString *)name;

/// 添加一个事务
/// @param transaction 事务
- (void)addTransaction:(QNTransaction *)transaction;

/// 移除一个事务
/// @param transaction 事务
- (void)removeTransaction:(QNTransaction *)transaction;

/// 在下一次循环执行事务, 该事务如果未被添加到事务列表，会自动添加
/// @param transaction 事务
- (void)performTransaction:(QNTransaction *)transaction;

/// 销毁资源 清空事务链表 销毁常驻线程
- (void)destroyResource;

@end

NS_ASSUME_NONNULL_END
