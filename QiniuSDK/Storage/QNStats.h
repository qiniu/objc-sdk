//
//  QNStats.h
//  QiniuSDK
//
//  Created by ltz on 9/21/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//



#import <Foundation/Foundation.h>
#import "AFNetworking.h"
#import "QNConfiguration.h"

#if TARGET_OS_IPHONE
#import "Reachability.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

//QNStats *defaultStatsManager;

@interface QNStats : NSObject

#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

#if TARGET_OS_IPHONE
@property (nonatomic, readonly) Reachability *wifiReach;
@property (nonatomic, readonly) CTTelephonyNetworkInfo *telephonyInfo;
@property (atomic, readonly) NetworkStatus reachabilityStatus;
#endif

// 切换网络的时候需要拿本地IP
@property (atomic, readonly) NSString *sip;

- (instancetype) init;
- (instancetype) initWithConfiguration: (QNConfiguration *) config;


- (void) addStatics: (NSMutableDictionary *) stat;
- (void) pushStats;
- (void) getOutIp;

@property int count;

#endif

@end

