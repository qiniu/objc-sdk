//
//  QNUtils.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/3/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#include <pthread.h>
#import "QNVersion.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@implementation QNUtils

+ (NSString *)sdkVerion{
    return kQiniuVersion;
}

+ (NSString *)sdkLanguage{
    return @"OC";
}

+ (int64_t)getCurrentProcessID {
    return [[NSProcessInfo processInfo] processIdentifier];
}

+ (int64_t)getCurrentThreadID {
    __uint64_t threadId = 0;
    if (pthread_threadid_np(0, &threadId)) {
           threadId = pthread_mach_thread_np(pthread_self());
    }
    return threadId;
}

+ (NSString *)systemName{
    NSString *name = nil;
    #if __IPHONE_OS_VERSION_MIN_REQUIRED
        name = [[UIDevice currentDevice] model];
    #else
        name = @"Mac OS X";
    #endif
    return name;
}

+ (NSString *)systemVersion{
    NSString *version = nil;
    #if __IPHONE_OS_VERSION_MIN_REQUIRED
        version = [[UIDevice currentDevice] systemVersion];
    #else
        version = [[NSProcessInfo processInfo] operatingSystemVersionString];
    #endif
    return version;
}

/// 信号格数
+ (NSNumber *)getCurrentSignalStrength{
    return @(3);
}

/// 网络类型
+ (NSString *)getCurrentNetworkType{
    NSString *type = nil;
    #if __IPHONE_OS_VERSION_MIN_REQUIRED
        type = [[UIDevice currentDevice] model];
    #else
        type = @"Mac OS X";
    #endif
    return type;
}

+ (NSTimeInterval)currentTimestamp{
    return [[NSDate date] timeIntervalSince1970] * 1000;
}


@end

