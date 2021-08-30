//
//  QNServerConfiguration.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/25.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNDnsPrefetch.h"
#import "QNConfiguration.h"
#import "QNServerConfigSynchronizer.h"
#import "QNServerConfigCache.h"
#import "QNServerConfigMonitor.h"

@interface QNServerConfigMonitor()

@property(nonatomic, strong)QNServerConfigCache *cache;

@end
@implementation QNServerConfigMonitor
- (instancetype)init {
    if (self = [super init]) {
        _cache = [[QNServerConfigCache alloc] init];
    }
    return self;
}

// 开始监控
- (void)startMonitor {
    
}

// 停止监控
- (void)endMonitor {
    
}

- (void)monitor {
    if (!self.cache.config.isValid) {
        QNServerConfig *config = [QNServerConfigSynchronizer getServerConfigFromServer];
        // 业务处理
        // 清理 region 缓存
        
        // dns 配置
        if (config.dnsConfig.enable) {
            kQNGlobalConfiguration.isDnsOpen = [config.dnsConfig.enable boolValue];
        }
        // 清理 dns 缓存
        if (config.regionConfig.clearId > self.cache.config.regionConfig.clearId &&
            config.regionConfig.clearCache) {
            [kQNDnsPrefetch clearDnsCache:nil];
        }
        // udp 配置
        if (config.dnsConfig.udpConfig.enable) {
            kQNGlobalConfiguration.udpDnsEnable = [config.dnsConfig.udpConfig.enable boolValue];
            if ([config.dnsConfig.udpConfig.ipv4Server isKindOfClass:[NSArray class]]) {
                kQNGlobalConfiguration.udpDnsServers = [config.dnsConfig.udpConfig.ipv4Server copy];
            }
        }
        
        // doh 配置
        if (config.dnsConfig.dohConfig.enable) {
            kQNGlobalConfiguration.dohEnable = [config.dnsConfig.dohConfig.enable boolValue];
            if ([config.dnsConfig.dohConfig.ipv4Server isKindOfClass:[NSArray class]]) {
                kQNGlobalConfiguration.dohServers = [config.dnsConfig.dohConfig.ipv4Server copy];
            }
        }
        self.cache.config = config;
    }
    
    if (!self.cache.userConfig.isValid) {
        QNServerUserConfig *config = [QNServerConfigSynchronizer getServerUserConfigFromServer];
        // 业务处理
        
        self.cache.userConfig = config;
    }
}

@end
