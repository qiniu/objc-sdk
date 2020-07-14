//
//  QNReportConfig.m
//  QiniuSDK
//
//  Created by 杨森 on 2020/7/14.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNReportConfig.h"
#import "QNUtils.h"

@implementation QNReportConfig

+ (instancetype)sharedInstance {
    
    static QNReportConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reportEnable = YES;
        _interval = 10;
        _serverURL = @"https://uplog.qbox.me/log/4";
        _recordDirectory = [NSString stringWithFormat:@"%@/report", [QNUtils sdkCacheDirectory]];
        _maxRecordFileSize = 2 * 1024 * 1024;
        _uploadThreshold = 4 * 1024;
        _timeoutInterval = 10;
    }
    return self;
}

@end
