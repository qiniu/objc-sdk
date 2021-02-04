//
//  QNUploadServerFreezeManager.h
//  QiniuSDK
//
//  Created by yangsen on 2020/6/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadServerFreezeManager : NSObject

/// 查询host是否被冻结
/// @param type 冻结Key
- (BOOL)isTypeFrozen:(NSString * _Nullable)type;

/// 冻结host
/// @param type 冻结Key
/// @param frozenTime 冻结时间
- (void)freezeType:(NSString * _Nullable)type frozenTime:(NSInteger)frozenTime;

/// 解冻host
/// @param type 冻结Key
- (void)unfreezeType:(NSString * _Nullable)type;

@end

NS_ASSUME_NONNULL_END
