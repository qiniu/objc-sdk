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

BOOL hasNSURLSession() {
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
    float sysVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (sysVersion < 7.0) {
        return NO;
    }
#else
    NSOperatingSystemVersion sysVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    if ((sysVersion.majorVersion <= 10 && sysVersion.minorVersion < 9)) {
        return NO;
    }
#endif
    return YES;
}

BOOL hasAts() {
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
    float sysVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (sysVersion < 9.0) {
        return NO;
    }
#else
    NSOperatingSystemVersion sysVersion = [[NSProcessInfo processInfo] operatingSystemVersion];

    if ((sysVersion.majorVersion <= 10 && sysVersion.minorVersion < 11)) {
        return NO;
    }
#endif
    return YES;
}

BOOL allowsArbitraryLoads() {
    if (!hasAts()) {
        return YES;
    }

    // for unit test
    NSDictionary* d = [[NSBundle mainBundle] infoDictionary];
    if (d == nil || d.count == 0) {
        return YES;
    }

    NSDictionary* sec = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSAppTransportSecurity"];
    if (sec == nil) {
        return NO;
    }
    NSNumber* ats = [sec objectForKey:@"NSAllowsArbitraryLoads"];
    if (ats == nil) {
        return NO;
    }
    return ats.boolValue;
}

BOOL isIOS8() {
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
    float sysVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if ((sysVersion >= 8.0) && sysVersion < 9.0) {
        return YES;
    }
#endif
    return NO;
}