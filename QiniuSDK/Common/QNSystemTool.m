//
//  QNSystemTool.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNSystemTool.h"
#include <pthread.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@implementation QNSystemTool
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

@end
