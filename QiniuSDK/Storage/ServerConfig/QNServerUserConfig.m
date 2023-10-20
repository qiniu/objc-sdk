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
    return [[QNServerUserConfig alloc] initWithDictionary:info];
}

- (nonnull id<QNCacheObject>)initWithDictionary:(nullable NSDictionary *)info {
    if (self = [super init]) {
        if (info) {
            self.ttl = [info[@"ttl"] longValue];
            self.http3Enable = info[@"http3"][@"enabled"];
            self.networkCheckEnable = info[@"network_check"][@"enabled"];
            
            if (self.ttl < 10) {
                self.ttl = 10;
            }
            
            NSMutableDictionary *mutableInfo = [info mutableCopy];
            if (info[@"timestamp"] != nil) {
                self.timestamp = [info[@"timestamp"] doubleValue];
            }
            if (self.timestamp == 0) {
                self.timestamp = [[NSDate date] timeIntervalSince1970];
                mutableInfo[@"timestamp"] = @(self.timestamp);
            }
            self.info = [mutableInfo copy];
        }
    }
    return self;
}

- (nullable NSDictionary *)toDictionary {
    return [self.info copy];
}

- (BOOL)isValid {
    return [[NSDate date] timeIntervalSince1970] < (self.timestamp + self.ttl);
}

@end
