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
    config.enable = info[@"enable"];
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
    config.enable = info[@"enable"];
    config.ipv4Server = [QNServerDnsServer config:info[@"ipv4"]];
    config.ipv6Server = [QNServerDnsServer config:info[@"ipv6"]];
    return config;
}
@end


@interface QNServerDnsConfig()
@property(nonatomic, assign)NSNumber *enable;
@property(nonatomic, assign)long clearId;
@property(nonatomic, assign)BOOL clearCache;
@property(nonatomic, strong)QNServerUdpDnsConfig *udpConfig;
@property(nonatomic, strong)QNServerDohConfig *dohConfig;
@end
@implementation QNServerDnsConfig
+ (instancetype)config:(NSDictionary *)info {
    QNServerDnsConfig *config = [[QNServerDnsConfig alloc] init];
    config.enable = info[@"enable"];
    config.clearId = [info[@"clear_id"] longValue];
    config.clearCache = [info[@"clear_cache"] longValue];
    config.dohConfig = [QNServerDohConfig config:info[@"doh"]];
    config.udpConfig = [QNServerUdpDnsConfig config:info[@"udp"]];
    return config;
}
@end


@interface QNServerConfig()
@property(nonatomic, strong)NSDictionary *info;
@property(nonatomic, assign)double timestamp;
@property(nonatomic, assign)long ttl;
@property(nonatomic, strong)QNServerRegionConfig *regionConfig;
@property(nonatomic, strong)QNServerDnsConfig *dnsConfig;
@end
@implementation QNServerConfig

+ (instancetype)config:(NSDictionary *)info {
    QNServerConfig *config = [[QNServerConfig alloc] init];
    config.info = [info copy];
    config.timestamp = [[NSDate date] timeIntervalSince1970];
    config.ttl = [info[@"ttl"] longValue];
    config.regionConfig = [QNServerRegionConfig config:info[@"region"]];
    config.dnsConfig = [QNServerDnsConfig config:info[@"dns"]];
    
    if (config.ttl < 10) {
        config.ttl = 10;
    }
    return config;
}

- (BOOL)isValid {
    return [[NSDate date] timeIntervalSince1970] < (self.timestamp + self.ttl);
}

@end
