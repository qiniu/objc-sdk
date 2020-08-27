//
//  QNUploadServerFreezeManager.h
//  QiniuSDK
//
//  Created by yangsen on 2020/6/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define kQNUploadServerFreezeManager [QNUploadServerFreezeManager shared]
@interface QNUploadServerFreezeManager : NSObject

+ (instancetype)shared;

/// 查询host是否被冻结
/// @param host host
/// @param type host类型
- (BOOL)isFrozenHost:(NSString *)host type:(NSString * _Nullable)type;

/// 冻结host
/// @param host host
/// @param type host类型
- (void)freezeHost:(NSString *)host type:(NSString * _Nullable)type;

@end

NS_ASSUME_NONNULL_END
