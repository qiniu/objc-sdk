//
//  QNServerUserConfig.h
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNServerUserConfig : NSObject

@property(nonatomic, assign, readonly)BOOL isValid;
@property(nonatomic, assign, readonly)long ttl;
@property(nonatomic, strong, readonly)NSNumber *http3Enable;
@property(nonatomic, strong, readonly)NSNumber *networkCheckEnable;

@property(nonatomic, strong, readonly)NSDictionary *info;

+ (instancetype)config:(NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
