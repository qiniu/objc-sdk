//
//  QNConfiguration.m
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"

@implementation QNConfiguration

@end


@implementation QNZone

- (instancetype)initWithUpHost:(NSString *)upHost
                  upHostBackup:(NSString *)upHostBackup
                          upIp:(NSString *)upIp {
    if (self = [super init]) {
        _upHost = upHost;
        _upHostBackup = upHostBackup;
        _upIp = upIp;
    }
    
    return self;
}

+ (instancetype)zone0 {
    return [[QNZone alloc] initWithUpHost:@"upload.qiniu.com" upHostBackup:@"up.qiniu.com" upIp:@"183.136.139.10"];
}

+ (instancetype)zone1 {
    return [[QNZone alloc] initWithUpHost:@"upload-z1.qiniu.com" upHostBackup:@"up-z1.qiniu.com" upIp:@"106.38.227.28"];
}

@end
