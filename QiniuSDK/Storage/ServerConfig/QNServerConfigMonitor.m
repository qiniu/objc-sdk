//
//  QNServerConfiguration.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/25.
//  Copyright © 2021 Qiniu. All rights reserved.
//
#import "QNLogUtil.h"
#import "QNDefine.h"
#import "QNAutoZone.h"
#import "QNDnsPrefetch.h"
#import "QNConfiguration.h"
#import "QNServerConfigSynchronizer.h"
#import "QNServerConfigCache.h"
#import "QNServerConfigMonitor.h"
#import "QNTransactionManager.h"

#define kQNServerConfigTransactionKey @"QNServerConfig"

@interface QNGlobalConfiguration(DnsDefaultServer)
@property(nonatomic, strong)NSArray *defaultDohIpv4Servers;
@property(nonatomic, strong)NSArray *defaultDohIpv6Servers;
@property(nonatomic, strong)NSArray *defaultUdpDnsIpv4Servers;
@property(nonatomic, strong)NSArray *defaultUdpDnsIpv6Servers;
@end
@implementation QNGlobalConfiguration(DnsDefaultServer)
@dynamic defaultDohIpv4Servers;
@dynamic defaultDohIpv6Servers;
@dynamic defaultUdpDnsIpv4Servers;
@dynamic defaultUdpDnsIpv6Servers;
@end

@interface QNServerConfigMonitor()

@property(nonatomic, assign)BOOL enable;
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
        _enable = true;
        _cache = [[QNServerConfigCache alloc] init];
    }
    return self;
}

+ (BOOL)enable {
    return [[QNServerConfigMonitor share] enable];
}

+ (void)setEnable:(BOOL)enable {
    [QNServerConfigMonitor share].enable = enable;
}

+ (NSString *)token {
    return QNServerConfigSynchronizer.token;
}

// 配置 token
+ (void)setToken:(NSString *)token {
    QNServerConfigSynchronizer.token = token;
}

// 开始监控
+ (void)startMonitor {
    if (![QNServerConfigMonitor share].enable) {
        return;
    }
    
    @synchronized (self) {
        BOOL isExist = [kQNTransactionManager existTransactionsForName:kQNServerConfigTransactionKey];
        if (isExist) {
            return;
        }
        
        QNTransaction *transaction = [QNTransaction timeTransaction:kQNServerConfigTransactionKey after:0 interval:10 action:^{
            [[QNServerConfigMonitor share] monitor];
        }];
        [kQNTransactionManager addTransaction:transaction];
    }
}

// 停止监控
+ (void)endMonitor {
    @synchronized (self) {
        NSArray *transactions = [kQNTransactionManager transactionsForName:kQNServerConfigTransactionKey];
        for (QNTransaction *transaction in transactions) {
            [kQNTransactionManager removeTransaction:transaction];
        }
    }
}

- (void)monitor {
    if (!self.enable) {
        return;
    }
    
    if (self.cache.config == nil) {
        QNServerConfig *config = [self.cache getConfigFromDisk];
        [self handleServerConfig:config];
        self.cache.config = config;
    }
    
    if (!self.cache.config.isValid) {
        [QNServerConfigSynchronizer getServerConfigFromServer:^(QNServerConfig * _Nonnull config) {
            if (config == nil) {
                return;
            }
            [self handleServerConfig:config];
            self.cache.config = config;
            [self.cache saveConfigToDisk:config];
        }];
    }
    
    if (self.cache.userConfig == nil) {
        QNServerUserConfig *config = [self.cache getUserConfigFromDisk];
        [self handleServerUserConfig:config];
        self.cache.userConfig = config;
    }
    
    if (!self.cache.userConfig.isValid) {
        [QNServerConfigSynchronizer getServerUserConfigFromServer:^(QNServerUserConfig * _Nonnull config) {
            if (config == nil) {
                return;
            }
            [self handleServerUserConfig:config];
            self.cache.userConfig = config;
            [self.cache saveUserConfigToDisk:config];
        }];
    }
}

- (void)handleServerConfig:(QNServerConfig *)config {
    if (config == nil) {
        return;
    }
    
    // 清理 region 缓存
    if (self.cache.config.regionConfig &&
        config.regionConfig.clearId > self.cache.config.regionConfig.clearId &&
        config.regionConfig.clearCache) {
        QNLogDebug(@"server config: clear region cache");
        [QNAutoZone clearCache];
    }
    
    // dns 配置
    if (config.dnsConfig.enable) {
        QNLogDebug(@"server config: dns enable %@", config.dnsConfig.enable);
        kQNGlobalConfiguration.isDnsOpen = [config.dnsConfig.enable boolValue];
    }
    
    // 清理 dns 缓存
    if (self.cache.config.dnsConfig &&
        config.dnsConfig.clearId > self.cache.config.dnsConfig.clearId &&
        config.dnsConfig.clearCache) {
        QNLogDebug(@"server config: clear dns cache");
        [kQNDnsPrefetch clearDnsCache:nil];
    }
    
    // udp 配置
    if (config.dnsConfig.udpConfig.enable) {
        QNLogDebug(@"server config: udp enable %@", config.dnsConfig.udpConfig.enable);
        kQNGlobalConfiguration.udpDnsEnable = [config.dnsConfig.udpConfig.enable boolValue];
    }
    
    if (config.dnsConfig.udpConfig.ipv4Server.isOverride &&
        [config.dnsConfig.udpConfig.ipv4Server.servers isKindOfClass:[NSArray class]]) {
        QNLogDebug(@"server config: udp config ipv4Server %@", config.dnsConfig.udpConfig.ipv4Server.servers);
        kQNGlobalConfiguration.defaultUdpDnsIpv4Servers = [config.dnsConfig.udpConfig.ipv4Server.servers copy];
    }
    if (config.dnsConfig.udpConfig.ipv6Server.isOverride &&
        [config.dnsConfig.udpConfig.ipv6Server.servers isKindOfClass:[NSArray class]]) {
        QNLogDebug(@"server config: udp config ipv6Server %@", config.dnsConfig.udpConfig.ipv6Server.servers);
        kQNGlobalConfiguration.defaultUdpDnsIpv6Servers = [config.dnsConfig.udpConfig.ipv6Server.servers copy];
    }
    
    // doh 配置
    if (config.dnsConfig.dohConfig.enable) {
        kQNGlobalConfiguration.dohEnable = [config.dnsConfig.dohConfig.enable boolValue];
        QNLogDebug(@"server config: doh enable %@", config.dnsConfig.dohConfig.enable);
    }
    if (config.dnsConfig.dohConfig.ipv4Server.isOverride &&
        [config.dnsConfig.dohConfig.ipv4Server.servers isKindOfClass:[NSArray class]]) {
        QNLogDebug(@"server config: doh config ipv4Server %@", config.dnsConfig.dohConfig.ipv4Server.servers);
        kQNGlobalConfiguration.defaultDohIpv4Servers = [config.dnsConfig.dohConfig.ipv4Server.servers copy];
    }
    if (config.dnsConfig.dohConfig.ipv6Server.isOverride &&
        [config.dnsConfig.dohConfig.ipv6Server.servers isKindOfClass:[NSArray class]]) {
        QNLogDebug(@"server config: doh config ipv6Server %@", config.dnsConfig.dohConfig.ipv6Server.servers);
        kQNGlobalConfiguration.defaultDohIpv6Servers = [config.dnsConfig.dohConfig.ipv6Server.servers copy];
    }
}

- (void)handleServerUserConfig:(QNServerUserConfig *)config {
    if (config == nil) {
        return;
    }
    if (config.networkCheckEnable) {
        QNLogDebug(@"server config: connect check enable %@", config.networkCheckEnable);
        kQNGlobalConfiguration.connectCheckEnable = [config.networkCheckEnable boolValue];
    }
}

@end
