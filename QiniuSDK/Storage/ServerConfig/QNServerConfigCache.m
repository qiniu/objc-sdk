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

- (instancetype)init {
    if (self = [super init]) {
        self.recorder = [QNFileRecorder fileRecorderWithFolder:[[QNUtils sdkCacheDirectory] stringByAppendingString:@"/ServerConfig"] error:nil];
    }
    return self;
}

//MARK: --- config
- (QNServerConfig *)getConfigFromDisk {
    NSData *data = nil;
    @synchronized (self) {
        data = [self.recorder get:kQNServerConfigDiskKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) {
            [self.recorder del:kQNServerConfigDiskKey];
        }
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
        @synchronized (self) {
            [self.recorder set:kQNServerConfigDiskKey data:data];
        }
    }
}

//MARK: --- user config
- (QNServerUserConfig *)getUserConfigFromDisk {
    NSData *data = nil;
    @synchronized (self) {
        data = [self.recorder get:kQNServerUserConfigDiskKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) {
            [self.recorder del:kQNServerUserConfigDiskKey];
        }
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
        @synchronized (self) {
            [self.recorder set:kQNServerUserConfigDiskKey data:data];
        }
    }
}

- (void)removeConfigCache {
    @synchronized (self) {
        [self.recorder del:kQNServerConfigDiskKey];
        [self.recorder del:kQNServerUserConfigDiskKey];
    }
}

@end
