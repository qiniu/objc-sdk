//
//  FormUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

#import "QNTestConfig.h"

@interface QNFormUploadTesT : XCTestCase

@property QNUploadManager *upManager;

@end

@implementation QNFormUploadTesT

- (void)setUp {
	[super setUp];
	_upManager = [[QNUploadManager alloc] init];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testUp {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;

	QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"foo":@"bar" } checkCrc:NO cancellationSignal:nil];
	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
	[self.upManager putData:data key:@"hello" token:g_token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	    testInfo = info;
	    testResp = resp;
	} option:opt];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	NSLog(@"%@", testResp);
	XCTAssert(testInfo.statusCode == 200, @"Pass");
	XCTAssert(testInfo.reqId, @"Pass");
}

- (void)testUpUnAuth {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;
	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
	NSString *token = @"noauth";
	[self.upManager putData:data key:@"hello" token:token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	    testInfo = info;
	    testResp = resp;
	} option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == 401, @"Pass");
	XCTAssert(testInfo.reqId, @"Pass");
}

@end
