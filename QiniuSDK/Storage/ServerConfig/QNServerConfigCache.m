//
//  QNServerConfigCache.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNServerConfigCache.h"
#import "QNUtils.h"
#import "QNFileRecorder.h"

#define kQNServerConfigDiskKey @"config"
#define kQNServerUserConfigDiskKey @"userConfig"

@interface QNServerConfigCache(){
    QNServerConfig *_config;
    QNServerUserConfig *_userConfig;
}
@property(nonatomic, strong)id<QNRecorderDelegate> recorder;
@end
@implementation QNServerConfigCache

- (void)initData{
    self.recorder = [QNFileRecorder fileRecorderWithFolder:[[QNUtils sdkCacheDirectory] stringByAppendingString:@"/ServerConfig"] error:nil];
}

//MARK: --- config
- (QNServerConfig *)config {
    if (_config == nil) {
        _config = [self getConfigFromDisk];
    }
    return _config;
}

- (void)setConfig:(QNServerConfig *)config {
    _config = config;
    [self saveConfigToDisk:config];
}

- (QNServerConfig *)getConfigFromDisk {
    NSData *data = [self.recorder get:kQNServerConfigDiskKey];
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        [self.recorder del:kQNServerConfigDiskKey];
        return nil;
    }
    return [QNServerConfig config:info];
}

- (void)saveConfigToDisk:(QNServerConfig *)config {
    if (self.recorder == nil || config.info == nil) {
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:config.info options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [self.recorder set:kQNServerConfigDiskKey data:data];
    }
}

//MARK: --- user config
- (QNServerUserConfig *)userConfig {
    if (_userConfig == nil) {
        _userConfig = [self getUserConfigFromDisk];
    }
    return _userConfig;
}

- (void)setUserConfig:(QNServerUserConfig *)userConfig {
    _userConfig = userConfig;
    [self saveUserConfigToDisk:userConfig];
}

- (QNServerUserConfig *)getUserConfigFromDisk {
    NSData *data = [self.recorder get:kQNServerUserConfigDiskKey];
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        [self.recorder del:kQNServerUserConfigDiskKey];
        return nil;
    }
    return [QNServerUserConfig config:info];
}

- (void)saveUserConfigToDisk:(QNServerUserConfig *)config {
    if (self.recorder == nil || config.info == nil) {
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:config.info options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [self.recorder set:kQNServerUserConfigDiskKey data:data];
    }
}

@end
