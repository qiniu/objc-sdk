//
//  QNInputStream.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/31.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNInputStream <NSObject>

/**
 * 读取 dataSize 大小的数据
 * 1. 当数据读取结束时，返回 nil
 * 2. 当数据未读取结束时，返回 NSData 不可为 nil, 但长度可以为 0, NSData 最大长度为 dataSize
 *
 * @param dataSize 期望读取的数据大小
 * @param error 读取过程中产生的错误；一般情况下当有 error 出现时，会调用 close 并终止数据读取
 */
- (NSData * _Nullable)readData:(NSInteger)dataSize error:(NSError ** _Nullable)error;

/**
 * 关闭数据流
 */
- (void)close;

@end

NS_ASSUME_NONNULL_END
