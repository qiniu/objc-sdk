//
//  QNResumeUploadTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

#import "QNTestConfig.h"
#import "QNTempFile.h"

@interface QNResumeUploadTest : XCTestCase
@property QNUploadManager *upManager;
@property BOOL inTravis;
@end

@implementation QNResumeUploadTest

- (void)setUp {
	[super setUp];
	_upManager = [[QNUploadManager alloc] init];
#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
	NSString *travis = [[NSProcessInfo processInfo]environment][@"QINIU_TEST_ENV"];
	if ([travis isEqualToString:@"travis"]) {
		_inTravis = YES;
	}
#endif
}

- (void)tearDown {
	[super tearDown];
}

- (void)testCancel {
	int size = 6 * 1024;
	NSURL *tempFile = [QNTempFile createTempfileWithSize:size * 1024];
	NSString *keyUp = [NSString stringWithFormat:@"%dk", size];
	__block NSString *key = nil;
	__block QNResponseInfo *info = nil;
	__block BOOL flag = NO;
	QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil progressHandler: ^(NSString *key, float percent) {
	    flag = YES;
	} params:@{ @"x:七牛":@"objc" } checkCrc:NO cancellationSignal: ^BOOL () {
	    return flag;
	}];
	[_upManager putFile:tempFile.path key:keyUp token:g_token complete: ^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
	    key = k;
	    info = i;
	} option:opt];

	AGWW_WAIT_WHILE(key == nil, 60 * 30);
	NSLog(@"info %@", info);
	XCTAssert(info.isCancelled, @"Pass");
	XCTAssert([keyUp isEqualToString:key], @"Pass");

	[QNTempFile removeTempfile:tempFile];
}

- (void)template:(int)size {
	NSURL *tempFile = [QNTempFile createTempfileWithSize:size * 1024];
	NSString *keyUp = [NSString stringWithFormat:@"%dk", size];
	__block NSString *key = nil;
	__block QNResponseInfo *info = nil;
	QNUploadOption *opt = [[QNUploadOption alloc] initWithProgessHandler: ^(NSString *key, float percent) {
	    NSLog(@"progress %f", percent);
	}];
	[_upManager putFile:tempFile.path key:keyUp token:g_token complete: ^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
	    key = k;
	    info = i;
	} option:opt];
	AGWW_WAIT_WHILE(key == nil, 60 * 30);
	NSLog(@"info %@", info);
	XCTAssert(info.isOK, @"Pass");
	XCTAssert(info.reqId, @"Pass");
	XCTAssert([keyUp isEqualToString:key], @"Pass");

	[QNTempFile removeTempfile:tempFile];
}

- (void)testNoKey {
	NSURL *tempFile = [QNTempFile createTempfileWithSize:600 * 1024];
	__block QNResponseInfo *info = nil;
	__block NSDictionary *testResp = nil;
	__block NSString *key = nil;
	[_upManager putFile:tempFile.path key:nil token:g_token complete: ^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
	    key = k;
	    info = i;
	    testResp = resp;
	} option:nil];
	AGWW_WAIT_WHILE(info == nil, 60 * 30);
	NSLog(@"resp %@", testResp);
	XCTAssert(info.isOK, @"Pass");
	XCTAssert(info.reqId, @"Pass");
	XCTAssert(key == nil, @"Pass");
	XCTAssert([@"FnwKMB9tve71u37IlABna6j4Gdyr" isEqualToString: testResp[@"key"]], @"Pass");
	[QNTempFile removeTempfile:tempFile];
}

- (void)test500k {
	[self template:500];
}

- (void)test600k {
	[self template:600];
}

#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED

- (void)test1M {
	if (_inTravis) {
		return;
	}
	[self template:1024];
}

- (void)test4M {
	if (_inTravis) {
		return;
	}
	[self template:4 * 1024];
}

- (void)test8M {
	if (_inTravis) {
		return;
	}
	[self template:8 * 1024 + 1];
}

#endif
@end
