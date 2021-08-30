//
//  QNServerConfigCache.h
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNServerConfig.h"
#import "QNServerUserConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNServerConfigCache : NSObject

@property(nonatomic, strong)QNServerConfig *config;
@property(nonatomic, strong)QNServerUserConfig *userConfig;

@end

NS_ASSUME_NONNULL_END
