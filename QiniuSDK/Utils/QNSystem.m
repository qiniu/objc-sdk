//
//  QNSystem.m
//  QiniuSDK
//
//  Created by bailong on 15/10/13.
//  Copyright © 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#else
#import <CoreServices/CoreServices.h>
#endif

BOOL isIpV6FullySupported(void) {
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
    float sysVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (sysVersion < 9.0) {
        return NO;
    }
#else
    NSOperatingSystemVersion sysVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (sysVersion.majorVersion < 10) {
        return NO;
    } else if (sysVersion.majorVersion == 10) {
        return sysVersion.minorVersion >= 11;
    }
#endif
    return YES;
}
