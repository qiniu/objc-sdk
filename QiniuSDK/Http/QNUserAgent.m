//
//  QNUserAgent.m
//  QiniuSDK
//
//  Created by bailong on 14-9-29.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MIN_REQUIRED
  #import <MobileCoreServices/MobileCoreServices.h>
  #import <UIKit/UIKit.h>
#else
  #import <CoreServices/CoreServices.h>
#endif

#import "QNUserAgent.h"
#import "QNVersion.h"

static NSString *clientId(void)
{
    long long   now_timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    int         r = arc4random() % 1000;

    return [NSString stringWithFormat:@"%lld%u", now_timestamp, r];
}

static NSString *_userAgent = nil;

NSString *QNUserAgent(void)
{
    if (_userAgent) {
        return _userAgent;
    }

#if __IPHONE_OS_VERSION_MIN_REQUIRED
        _userAgent = [NSString stringWithFormat:@"QiniuObject-C/%@ (%@; iOS %@; %@)", kQiniuVersion, [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], clientId()];
#else
        _userAgent = [NSString stringWithFormat:@"QiniuObject-C/%@ (Mac OS X %@; %@)", kQiniuVersion, [[NSProcessInfo processInfo] operatingSystemVersionString], clientId()];
#endif
    return _userAgent;
}
