//
//  QNConfiguration.m
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"

const UInt32 kQNBlockSize = 4 * 1024 * 1024;

@implementation QNConfiguration

+ (instancetype)build:(QNConfigurationBuilderBlock)block {
	QNConfigurationBuilder *builder = [[QNConfigurationBuilder alloc] init];
	block(builder);
	return [[QNConfiguration alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(QNConfigurationBuilder *)builder {
	if (self = [super init]) {
		_upHost = builder.zone.upHost;
		_upHostBackup = builder.zone.upHostBackup;

		_upPort = builder.upPort;

		_chunkSize = builder.chunkSize;
		_putThreshold = builder.putThreshold;
		_retryMax = builder.retryMax;
		_timeoutInterval = builder.timeoutInterval;

		_recorder = builder.recorder;
		_recorderKeyGen = builder.recorderKeyGen;

		_proxy = builder.proxy;

		_converter = builder.converter;
		if (builder.converter == nil) {
			_upIp = builder.zone.upIp;
		}
	}
	return self;
}

@end

@implementation QNConfigurationBuilder

- (instancetype)init {
	if (self = [super init]) {
		_zone = [QNZone zone0];
		_chunkSize = 256 * 1024;
		_putThreshold = 512 * 1024;
		_retryMax = 5;
		_timeoutInterval = 60;

		_recorder = nil;
		_recorderKeyGen = nil;

		_proxy = nil;
		_converter = nil;

		_upPort = 80;
	}
	return self;
}

@end

@implementation QNZone

- (instancetype)initWithUpHost:(NSString *)upHost
                  upHostBackup:(NSString *)upHostBackup
                          upIp:(NSString *)upIp {
	if (self = [super init]) {
		_upHost = upHost;
		_upHostBackup = upHostBackup;
		_upIp = upIp;
	}

	return self;
}

+ (instancetype)zone0 {
	static QNZone *z0 = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		z0 = [[QNZone alloc] initWithUpHost:@"upload.qiniu.com" upHostBackup:@"up.qiniu.com" upIp:@"183.136.139.10"];
	});
	return z0;
}

+ (instancetype)zone1 {
	static QNZone *z1 = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		z1 = [[self alloc] initWithUpHost:@"upload-z1.qiniu.com" upHostBackup:@"up-z1.qiniu.com" upIp:@"106.38.227.28"];
	});
	return z1;
}

@end
