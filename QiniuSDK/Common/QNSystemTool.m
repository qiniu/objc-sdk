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
+ (NSString *)getCurrentNetworkType {
    
    __block NSString *networkTypeString = @"none";
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        if ([[app valueForKeyPath:@"_statusBar"] isKindOfClass:NSClassFromString(@"UIStatusBar_Modern")])
            return;
        
        NSArray *subviews = [[[app valueForKeyPath:@"statusBar"] valueForKeyPath:@"foregroundView"] subviews];
        for (id subview in subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"UIStatusBarDataNetworkItemView")]) {
                int networkType = [[subview valueForKeyPath:@"dataNetworkType"] intValue];
                switch (networkType) {
                    case 0:
                        networkTypeString = @"none";
                    case 1:
                        networkTypeString = @"2g";
                    case 2:
                        networkTypeString = @"3g";
                    case 3:
                        networkTypeString = @"4g";
                    case 5:
                        networkTypeString = @"wifi";
                    default:
                        break;
                }
            }
        }
    });
    return networkTypeString;
}

+ (int64_t)getCurrentNetworkSignalStrength {
    
    __block int64_t networkSignalStrength = 0;
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        // iPhone X
        if ([[app valueForKeyPath:@"_statusBar"] isKindOfClass:NSClassFromString(@"UIStatusBar_Modern")])
            return;
        NSArray *subviews = [[[app valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
        UIView *dataNetworkItemView = nil;
        
        for (UIView * subview in subviews)
        {
            if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
                dataNetworkItemView = subview;
                break;
            }
        }
        networkSignalStrength = [[dataNetworkItemView valueForKey:@"_wifiStrengthBars"] intValue];
    });
    return networkSignalStrength;
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
@end
