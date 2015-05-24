//
//  QNHttpTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/3.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNHttpManager.h"
#import "QNResponseInfo.h"

#import "QNConfiguration.h"

@interface QNHttpTest : XCTestCase
@property QNHttpManager *httpManager;
@end

@implementation QNHttpTest

- (void)setUp {
	[super setUp];
	_httpManager = [[QNHttpManager alloc] init];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testPost {
	__block QNResponseInfo *testInfo = nil;
	NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
	[_httpManager post:@"http://www.baidu.com" withData:data withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];
	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);

	XCTAssert(testInfo.reqId == nil, @"Pass");

	testInfo = nil;

	[_httpManager post:@"http://up.qiniu.com" withData:nil withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.reqId, @"Pass");

	testInfo = nil;
	[_httpManager post:@"http://httpbin.org/status/500" withData:nil withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == 500, @"Pass");
	XCTAssert(testInfo.error != nil, @"Pass");

	testInfo = nil;
	[_httpManager post:@"http://httpbin.org/status/418" withData:nil withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == 418, @"Pass");
	XCTAssert(testInfo.error != nil, @"Pass");

	testInfo = nil;
	[_httpManager post:@"http://httpbin.org/status/200" withData:nil withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == 200, @"Pass");
	XCTAssert(!testInfo.isOK, @"Pass");
	XCTAssert(testInfo.error != nil, @"Pass");
}

- (void)testUrlConvert {
	QNUrlConvert c = ^NSString *(NSString *url) {
		return [url stringByReplacingOccurrencesOfString:@"upnono" withString:@"up"];
	};

	QNHttpManager *httpManager = [[QNHttpManager alloc] initWithTimeout:60 urlConverter:c backupIp:nil];
	NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
	__block QNResponseInfo *testInfo = nil;
	[httpManager post:@"http://upnono.qiniu.com" withData:data withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.reqId, @"Pass");
	XCTAssert([testInfo.host isEqual:@"up.qiniu.com"], @"Pass");
}

- (void)testPostIp {
	__block QNResponseInfo *testInfo = nil;
	QNHttpManager *httpManager = [[QNHttpManager alloc] initWithTimeout:60 urlConverter:nil backupIp:[QNZone zone0].upIp];
	[httpManager post:@"http://upnonono.qiniu.com" withData:nil withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
	    testInfo = info;
	} withProgressBlock:nil withCancelBlock:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.reqId, @"Pass");
}

@end
