//
//  QNServerConfigCache.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNServerConfigCache.h"
#import "QNUtils.h"
#import "QNCache.h"

#define kQNServerConfigDiskKey @"config"
#define kQNServerUserConfigDiskKey @"userConfig"

@interface QNServerConfigCache(){
    QNServerConfig *_config;
    QNServerUserConfig *_userConfig;
}
@property(nonatomic, strong) QNCache *configCache;
@property(nonatomic, strong) QNCache *userConfigCache;
@end
@implementation QNServerConfigCache

- (instancetype)init {
    if (self = [super init]) {
        QNCacheOption *option = [[QNCacheOption alloc] init];
        option.version = @"v1.0.0";
        self.configCache = [QNCache cache:[QNServerConfig class] option:option];
        
        option = [[QNCacheOption alloc] init];
        option.version = @"v1.0.0";
        self.userConfigCache = [QNCache cache:[QNServerUserConfig class] option:option];
    }
    return self;
}

//MARK: --- config
- (QNServerConfig *)getConfigFromDisk {
    return [self.configCache cacheForKey:kQNServerConfigDiskKey];
}

- (void)saveConfigToDisk:(QNServerConfig *)config {
    [self.configCache cache:config forKey:kQNServerConfigDiskKey atomically:true];
}

//MARK: --- user config
- (QNServerUserConfig *)getUserConfigFromDisk {
    return [self.userConfigCache cacheForKey:kQNServerUserConfigDiskKey];
}

- (void)saveUserConfigToDisk:(QNServerUserConfig *)config {
    [self.userConfigCache cache:config forKey:kQNServerUserConfigDiskKey atomically:true];
}

- (void)removeConfigCache {
    @synchronized (self) {
        [self.configCache clearMemoryCache];
        [self.configCache clearDiskCache];
        [self.userConfigCache clearMemoryCache];
        [self.userConfigCache clearDiskCache];
    }
}

@end
