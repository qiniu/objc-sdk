//
//  QNCollectorConfig.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNReportConfig.h"

@implementation QNReportConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordEnable = YES;
        _interval = 10;
        _serverURL = @"https://uplog.qbox.me/log/3";
        _recordDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.qiniu.report"];
        _maxRecordFileSize = 2 * 1024 * 1024;
        _uploadThreshold = 4 * 1024;
        _timeoutInterval = 10;
    }
    return self;
}

@end
