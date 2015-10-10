//
//  QNDownloadManager.m
//  QiniuSDK
//
//  Created by ltz on 9/10/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//



#import <Foundation/Foundation.h>
#include <arpa/inet.h>

#import "QNAsyncRun.h"
#import "HappyDNS.h"
#import "AFNetworking.h"
#import "QNConfiguration.h"
#import "QNDownloadManager.h"
#import "QNDownloadTask.h"


@interface QNDownloadManager ()

@property (nonatomic) AFURLSessionManager *manager;

@end

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

- (QNDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request
                                    progress:(NSProgress *)progress
                                 destination:(NSURL * (^__strong)(NSURL *__strong, NSURLResponse *__strong))destination
                           completionHandler:(void (^__strong)(NSURLResponse *__strong, NSURL *__strong, NSError *__strong))completionHandler {

	NSMutableDictionary *stats = [[NSMutableDictionary alloc] init];

	return [[QNDownloadTask alloc]initWithStats:stats
	        manager:self request:request progress:progress destination:destination completionHandler:completionHandler];
}

#endif

@end

