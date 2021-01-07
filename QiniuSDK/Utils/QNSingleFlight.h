//
//  QNSingleFlight.h
//  QiniuSDK
//
//  Created by yangsen on 2021/1/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^QNSingleFlightComplete)(id _Nullable value, NSError * _Nullable error);
typedef void(^QNSingleFlightAction)(QNSingleFlightComplete _Nonnull complete);

@interface QNSingleFlight : NSObject

/**
 * 异步 SingleFlight 执行函数
 * @param key actionHandler 对应的 key，同一时刻同一个 key 最多只有一个对应的 actionHandler 在执行
 * @param actionHandler 执行函数，注意：actionHandler 有且只能回调一次
 * @param completeHandler  single flight 执行 actionHandler 后的完成回调
 */
- (void)perform:(NSString * _Nullable)key
         action:(QNSingleFlightAction _Nonnull)action
       complete:(QNSingleFlightComplete _Nullable)complete;

@end

NS_ASSUME_NONNULL_END
