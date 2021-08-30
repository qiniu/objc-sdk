//
//  QNServerUserConfig.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNServerUserConfig.h"

@interface QNServerUserConfig()
@property(nonatomic, strong)NSDictionary *info;
@property(nonatomic, assign)double timestamp;
@property(nonatomic, assign)long ttl;
@property(nonatomic, strong)NSNumber *http3Enable;
@property(nonatomic, strong)NSNumber *retryMax;
@property(nonatomic, strong)NSNumber *networkCheckEnable;
@end
@implementation QNServerUserConfig

+ (instancetype)config:(NSDictionary *)info {
    QNServerUserConfig *config = [[QNServerUserConfig alloc] init];
    config.timestamp = [[NSDate date] timeIntervalSince1970];
    config.info = [info copy];
    config.ttl = [info[@"ttl"] longValue];
    config.http3Enable = info[@"http3"][@"enabled"];
    config.retryMax = info[@"retryMax"];
    config.networkCheckEnable = info[@"network_check"][@"enabled"];
    
    if (config.ttl < 10) {
        config.ttl = 10;
    }
    return config;
}

- (BOOL)isValid {
    return [[NSDate date] timeIntervalSince1970] > (self.timestamp + self.ttl);
}

@end
