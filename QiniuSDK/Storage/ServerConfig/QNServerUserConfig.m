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
    config.ttl = [info[@"ttl"] longValue];
    config.http3Enable = info[@"http3"][@"enabled"];
    config.networkCheckEnable = info[@"network_check"][@"enabled"];
    
    if (config.ttl < 10) {
        config.ttl = 10;
    }
    
    NSMutableDictionary *mutableInfo = [info mutableCopy];
    if (info[@"timestamp"] != nil) {
        config.timestamp = [info[@"timestamp"] doubleValue];
    }
    if (config.timestamp == 0) {
        config.timestamp = [[NSDate date] timeIntervalSince1970];
        mutableInfo[@"timestamp"] = @(config.timestamp);
    }
    config.info = [mutableInfo copy];
    return config;
}

- (BOOL)isValid {
    return [[NSDate date] timeIntervalSince1970] < (self.timestamp + self.ttl);
}

@end
