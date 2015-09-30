//
//  QNStats.h
//  QiniuSDK
//
//  Created by ltz on 9/21/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import "AFNetworking.h"
#import "QNConfiguration.h"
#import "Reachability.h"

//QNStats *defaultStatsManager;

@interface QNStats : NSObject

@property (nonatomic) QNConfiguration *config;
@property (nonatomic) AFHTTPRequestOperationManager *httpManager;
@property (nonatomic) NSMutableArray *statsBuffer;
@property (nonatomic) NSLock *bufLock;

@property (nonatomic) NSTimer *pushTimer;
@property (nonatomic) NSTimer *getIPTimer;
@property (nonatomic) Reachability *wifiReach;
@property (nonatomic) CTTelephonyNetworkInfo *telephonyInfo;

// 切换网络的时候需要拿本地IP
@property (atomic) NSString *sip;

@property (atomic) NetworkStatus reachabilityStatus;
// ...
@property (atomic) NSString *radioAccessTechnology;

@property (nonatomic) NSString *phoneModel; // dev
@property (nonatomic) NSString *systemName; // os
@property (nonatomic) NSString *systemVersion; // sysv
@property (nonatomic) NSString *appName;  // app
@property (nonatomic) NSString *appVersion; // appv

- (instancetype) init;
- (instancetype) initWithConfiguration: (QNConfiguration *) config;


- (void) addStatics: (NSMutableDictionary *) stat;
- (void) pushStats;
- (void) getOutIp;

@property int count;

@end