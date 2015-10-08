//
//  QNDownloadManager.m
//  QiniuSDK
//
//  Created by ltz on 9/10/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//



#import <Foundation/Foundation.h>
#include <arpa/inet.h>

//#if 1 == 1


#import "QNAsyncRun.h"
#import "HappyDNS.h"
#import "AFNetworking.h"
#import "QNConfiguration.h"
#import "QNDownloadManager.h"
#import "QNDownloadTask.h"

@implementation QNDownloadManager

#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)


- (instancetype) init {

	return [self initWithConfiguration:nil sessionConfiguration:nil statsManager:nil];
}

- (instancetype) initWithConfiguration:(QNConfiguration *)config
                  sessionConfiguration:(AFURLSessionManager *)manager
                          statsManager:(QNStats *)statsManager {

	self = [super init];
	if (config == nil) {
		config = [QNConfiguration build: ^(QNConfigurationBuilder *builder) {}];
	}
	_config = config;

	if (manager == nil) {
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
		manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
	}
	_manager = manager;

	// TODO: isGatherStats
	if (statsManager == nil) {
		statsManager = [[QNStats alloc] initWithConfiguration:config];
	}
	_statsManager = statsManager;

	return self;
}

- (NSData *) dataWithContentsOfURL:(NSString *) url {
	return nil;
}

- (QNDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request
                                    progress:(NSProgress *)progress
                                 destination:(NSURL * (^__strong)(NSURL *__strong, NSURLResponse *__strong))destination
                           completionHandler:(void (^__strong)(NSURLResponse *__strong, NSURL *__strong, NSError *__strong))completionHandler {

	NSMutableDictionary *stats = [[NSMutableDictionary alloc] init];

	return [[QNDownloadTask alloc]initWithStats:stats
	        manager:self request:request progress:progress destination:destination completionHandler:completionHandler];
}

+ (BOOL) isValidIPAddress:(NSString *)ip {
	const char *utf8 = [ip UTF8String];
	if (utf8 == nil) {
		return true;
	}
	int success;

	struct in_addr dst;
	success = inet_pton(AF_INET, utf8, &dst);
	if (success != 1) {
		struct in6_addr dst6;
		success = inet_pton(AF_INET6, utf8, &dst6);
	}

	return success == 1;
}

#endif

@end

