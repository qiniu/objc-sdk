//
//  QNSystemTool.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNSystemTool.h"
#include <pthread.h>

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
@end
