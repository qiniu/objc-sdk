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
	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
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

@end
