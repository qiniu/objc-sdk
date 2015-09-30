//
//  QNStats.m
//  QiniuSDK
//
//  Created by ltz on 9/21/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//

#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import "QNStats.h"
#import "QNConfiguration.h"
#import "Reachability.h"

@implementation QNStats

- (instancetype) init {

	return [self initWithConfiguration:nil];
}

- (instancetype) initWithConfiguration: (QNConfiguration *) config {

	self = [super init];

	if (config == nil) {
		config = [QNConfiguration build: ^(QNConfigurationBuilder *builder) {}];
	}
	_config = config;

	_statsBuffer = [[NSMutableArray alloc] init];
	_bufLock = [[NSLock alloc] init];

	_httpManager = [[AFHTTPRequestOperationManager alloc] init];
	_httpManager.responseSerializer = [AFJSONResponseSerializer serializer];

	_count = 0;

	// get out ip first time
	[self getOutIp];

	// radio access technology
	_telephonyInfo = [CTTelephonyNetworkInfo new];
	_radioAccessTechnology = _telephonyInfo.currentRadioAccessTechnology;

	NSLog(@"Current Radio Access Technology: %@", _radioAccessTechnology);
	[NSNotificationCenter.defaultCenter addObserverForName:CTRadioAccessTechnologyDidChangeNotification
	 object:nil
	 queue:nil
	 usingBlock:^(NSNotification *note) {
	         _radioAccessTechnology = _telephonyInfo.currentRadioAccessTechnology;
	         NSLog(@"New Radio Access Technology: %@", _telephonyInfo.currentRadioAccessTechnology);
	         [self getOutIp];
	 }];

	// WiFi, WLAN, or nothing
	_wifiReach = [Reachability reachabilityForInternetConnection];
	_reachabilityStatus = _wifiReach.currentReachabilityStatus;


	[NSNotificationCenter.defaultCenter addObserverForName:kReachabilityChangedNotification
	 object:nil
	 queue:nil
	 usingBlock:^(NSNotification *note) {
	         _reachabilityStatus = _wifiReach.currentReachabilityStatus;

	         if (_reachabilityStatus != NotReachable) {
	                 [self getOutIp];
		 }
	 }];
	[_wifiReach startNotifier];

	// timer for push
	_pushTimer = [NSTimer scheduledTimerWithTimeInterval:_config.pushStatIntervalS target:self selector:@selector(pushStats) userInfo:nil repeats:YES];
	[_pushTimer fire];

	_getIPTimer = [NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(getOutIp) userInfo:nil repeats:YES];
	[_getIPTimer fire];

	// init device information
	_phoneModel = [[UIDevice currentDevice] model];
	_systemName = [[UIDevice currentDevice] systemName];
	_systemVersion = [[UIDevice currentDevice] systemVersion];

	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	_appName = [info objectForKey:@"CFBundleDisplayName"];
	NSString *majorVersion = [info objectForKey:@"CFBundleShortVersionString"];
	NSString *minorVersion = [info objectForKey:@"CFBundleVersion"];
	_appVersion = [NSString stringWithFormat:@"%@(%@)", majorVersion, minorVersion];

	if (_appName == nil) {
		_appName = @"";
	}
	if (_appVersion == nil) {
		_appVersion = @"";
	}

	return self;
}

- (void) addStatics:(NSMutableDictionary *)stat {

	[_bufLock lock];
	[_statsBuffer addObject:stat];
	[_bufLock unlock];
}

- (void) pushStats {

	@synchronized(self) {

		if (_reachabilityStatus == NotReachable) {
			return;
		}

		[_bufLock lock];
		NSMutableArray *reqs = [[NSMutableArray alloc] initWithArray:_statsBuffer copyItems:YES];
		[_statsBuffer removeAllObjects];
		[_bufLock unlock];

		if ([reqs count]) {
			NSDictionary *parameters = @{@"dev": _phoneModel, @"os": _systemName, @"sysv": _systemVersion,
				                     @"app": _appName, @"appv": _appVersion,
				                     @"reqs": reqs, @"v": @"0.1"};

			NSURLRequest *req = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:[_config.statsHost stringByAppendingString:@"/v1/stats"] parameters:parameters error:nil];

			AFHTTPRequestOperation *operation = [_httpManager HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			                                             _count += [reqs count];

							     } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			                                             NSLog(@"post stats failed, %@", error);
							     }];
			[_httpManager.operationQueue addOperation:operation];
		}
	}
}


- (void) getOutIp {

	[_httpManager GET:[_config.statsHost stringByAppendingString:@"/v1/ip"] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
	         NSDictionary *rst = (NSDictionary *)responseObject;
	         _sip = [rst valueForKey:@"ip"];
	         NSLog(@"sip: %@\n", _sip);
	 } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
	         NSLog(@"get ip failed: %@", error);
	 }];
}

@end
