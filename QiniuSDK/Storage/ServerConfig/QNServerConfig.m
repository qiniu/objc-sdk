//
//  QNServerConfig.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNServerConfig.h"

@interface QNServerRegionConfig()
@property(nonatomic, assign)long clearId;
@property(nonatomic, assign)BOOL clearCache;
@end
@implementation QNServerRegionConfig
+ (instancetype)config:(NSDictionary *)info {
    QNServerRegionConfig *config = [[QNServerRegionConfig alloc] init];
    config.clearId = [info[@"clear_id"] longValue];
    config.clearCache = [info[@"clear_cache"] longValue];
    return config;
}
@end

@interface QNServerDnsServer()
@property(nonatomic, assign)BOOL isOverride;
@property(nonatomic, strong)NSArray <NSString *> *servers;
@end
@implementation QNServerDnsServer
+ (instancetype)config:(NSDictionary *)info {
    QNServerDnsServer *config = [[QNServerDnsServer alloc] init];
    config.isOverride = [info[@"override_default"] boolValue];
    if (info[@"ips"] && [info[@"ips"] isKindOfClass:[NSArray class]]) {
        config.servers = info[@"ips"];
    } else if ([info[@"urls"] isKindOfClass:[NSArray class]]){
        config.servers = info[@"urls"];
    }
    return config;
}
@end

@interface QNServerDohConfig()
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, strong)QNServerDnsServer *ipv4Server;
@property(nonatomic, strong)QNServerDnsServer *ipv6Server;
@end
@implementation QNServerDohConfig
+ (instancetype)config:(NSDictionary *)info {
    QNServerDohConfig *config = [[QNServerDohConfig alloc] init];
    config.enable = info[@"enabled"];
    config.ipv4Server = [QNServerDnsServer config:info[@"ipv4"]];
    config.ipv6Server = [QNServerDnsServer config:info[@"ipv6"]];
    return config;
}
@end

@interface QNServerUdpDnsConfig()
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, strong)QNServerDnsServer *ipv4Server;
@property(nonatomic, strong)QNServerDnsServer *ipv6Server;
@end
@implementation QNServerUdpDnsConfig
+ (instancetype)config:(NSDictionary *)info {
    QNServerUdpDnsConfig *config = [[QNServerUdpDnsConfig alloc] init];
    config.enable = info[@"enabled"];
    config.ipv4Server = [QNServerDnsServer config:info[@"ipv4"]];
    config.ipv6Server = [QNServerDnsServer config:info[@"ipv6"]];
    return config;
}
@end


@interface QNServerDnsConfig()
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, assign)long clearId;
@property(nonatomic, assign)BOOL clearCache;
@property(nonatomic, strong)QNServerUdpDnsConfig *udpConfig;
@property(nonatomic, strong)QNServerDohConfig *dohConfig;
@end
@implementation QNServerDnsConfig
+ (instancetype)config:(NSDictionary *)info {
    QNServerDnsConfig *config = [[QNServerDnsConfig alloc] init];
    config.enable = info[@"enabled"];
    config.clearId = [info[@"clear_id"] longValue];
    config.clearCache = [info[@"clear_cache"] longValue];
    config.dohConfig = [QNServerDohConfig config:info[@"doh"]];
    config.udpConfig = [QNServerUdpDnsConfig config:info[@"udp"]];
    return config;
}
@end


@interface QNConnectCheckConfig()
@property(nonatomic, assign)BOOL isOverride;
@property(nonatomic, strong)NSNumber *enable;
@property(nonatomic, strong)NSNumber *timeoutMs;
@property(nonatomic, strong)NSArray <NSString *> *urls;
@end
@implementation QNConnectCheckConfig
+ (instancetype)config:(NSDictionary *)info {
    QNConnectCheckConfig *config = [[QNConnectCheckConfig alloc] init];
    config.isOverride = [info[@"override_default"] boolValue];
    config.enable = info[@"enabled"];
    config.timeoutMs = info[@"timeout_ms"];
    if (info[@"urls"] && [info[@"urls"] isKindOfClass:[NSArray class]]) {
        config.urls = info[@"urls"];
    }
    return config;
}
@end


@interface QNServerConfig()
@property(nonatomic, strong)NSDictionary *info;
@property(nonatomic, assign)double timestamp;
@property(nonatomic, assign)long ttl;
@property(nonatomic, strong)QNServerRegionConfig *regionConfig;
@property(nonatomic, strong)QNServerDnsConfig    *dnsConfig;
@property(nonatomic, strong)QNConnectCheckConfig *connectCheckConfig;
@end
@implementation QNServerConfig

+ (instancetype)config:(NSDictionary *)info {
    return [[QNServerConfig alloc] initWithDictionary:info];
}

- (nonnull id<QNCacheObject>)initWithDictionary:(nullable NSDictionary *)info {
    if (self = [self init]) {
        if (info) {
            self.ttl = [info[@"ttl"] longValue];
            self.regionConfig = [QNServerRegionConfig config:info[@"region"]];
            self.dnsConfig = [QNServerDnsConfig config:info[@"dns"]];
            self.connectCheckConfig = [QNConnectCheckConfig config:info[@"connection_check"]];
            
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
