//
//  QNServerConfiguration.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/25.
//  Copyright © 2021 Qiniu. All rights reserved.
//
#import "QNDefine.h"
#import "QNAutoZone.h"
#import "QNDnsPrefetch.h"
#import "QNConfiguration.h"
#import "QNServerConfigSynchronizer.h"
#import "QNServerConfigCache.h"
#import "QNServerConfigMonitor.h"
#import "QNTransactionManager.h"

#define kQNServerConfigTransactionKey @"QNServerConfig"

@interface QNServerConfigMonitor()

@property(nonatomic, strong)QNServerConfigCache *cache;

@end
@implementation QNServerConfigMonitor
+ (instancetype)share {
    static QNServerConfigMonitor *monitor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitor = [[QNServerConfigMonitor alloc] init];
    });
    return monitor;
}

- (instancetype)init {
    if (self = [super init]) {
        _cache = [[QNServerConfigCache alloc] init];
    }
    return self;
}

// 开始监控
- (void)startMonitor {
    BOOL isExist = [kQNTransactionManager existTransactionsForName:kQNServerConfigTransactionKey];
    if (isExist) {
        return;
    }
    
    kQNWeakSelf;
    QNTransaction *transaction = [QNTransaction timeTransaction:kQNServerConfigTransactionKey after:0 interval:10 action:^{
        kQNStrongSelf;
        [self monitor];
    }];
    [kQNTransactionManager addTransaction:transaction];
}

// 停止监控
- (void)endMonitor {
    NSArray *transactions = [kQNTransactionManager transactionsForName:kQNServerConfigTransactionKey];
    for (QNTransaction *transaction in transactions) {
        [kQNTransactionManager removeTransaction:transaction];
    }
}

- (void)monitor {
    if (!self.cache.config.isValid) {
        QNServerConfig *config = [QNServerConfigSynchronizer getServerConfigFromServer];
        // 清理 region 缓存
        [QNAutoZone clearCache];
        
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
                kQNGlobalConfiguration.udpDnsIpv4Servers = [config.dnsConfig.udpConfig.ipv4Server copy];
            }
            if ([config.dnsConfig.udpConfig.ipv6Server isKindOfClass:[NSArray class]]) {
                kQNGlobalConfiguration.udpDnsIpv6Servers = [config.dnsConfig.udpConfig.ipv6Server copy];
            }
        }
        // doh 配置
        if (config.dnsConfig.dohConfig.enable) {
            kQNGlobalConfiguration.dohEnable = [config.dnsConfig.dohConfig.enable boolValue];
            if ([config.dnsConfig.dohConfig.ipv4Server isKindOfClass:[NSArray class]]) {
                kQNGlobalConfiguration.dohIpv4Servers = [config.dnsConfig.dohConfig.ipv4Server copy];
            }
            if ([config.dnsConfig.dohConfig.ipv6Server isKindOfClass:[NSArray class]]) {
                kQNGlobalConfiguration.dohIpv6Servers = [config.dnsConfig.dohConfig.ipv6Server copy];
            }
        }
        
        self.cache.config = config;
    }
    
    if (!self.cache.userConfig.isValid) {
        QNServerUserConfig *config = [QNServerConfigSynchronizer getServerUserConfigFromServer];
        
        if (config.networkCheckEnable) {
            kQNGlobalConfiguration.connectCheckEnable = [config.networkCheckEnable boolValue];
        }
        self.cache.userConfig = config;
    }
}

@end
