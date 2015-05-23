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

static NSString *clientId(void) {
	long long now_timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
	int r = arc4random() % 1000;
	return [NSString stringWithFormat:@"%lld%u", now_timestamp, r];
}

NSString *QNUserAgent(void) {
	static NSString *ua = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
#if __IPHONE_OS_VERSION_MIN_REQUIRED
		ua =  [NSString stringWithFormat:@"QiniuObject-C/%@ (%@; iOS %@; %@)", kQiniuVersion, [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], clientId()];
#else
		ua = [NSString stringWithFormat:@"QiniuObject-C/%@ (Mac OS X %@; %@)", kQiniuVersion, [[NSProcessInfo processInfo] operatingSystemVersionString], clientId()];
#endif
	});
	return ua;
}
