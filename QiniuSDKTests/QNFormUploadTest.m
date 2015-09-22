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
	_upManager = [QNUploadManager sharedInstanceWithRecorder:nil recorderKeyGenerator:nil];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testUp {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;

	QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"x:foo":@"bar" } checkCrc:YES cancellationSignal:nil];
	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
	[self.upManager putData:data key:@"你好" token:g_token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	         testInfo = info;
	         testResp = resp;
	 } option:opt];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	NSLog(@"%@", testResp);
	XCTAssert(testInfo.isOK, @"Pass");
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

- (void)testNoData {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;
	NSString *token = @"noauth";
	[self.upManager putData:nil key:@"hello" token:token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	         testInfo = info;
	         testResp = resp;
	 } option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");
}

- (void)testNoFile {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;
	NSString *token = @"noauth";
	[self.upManager putFile:nil key:@"hello" token:token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	         testInfo = info;
	         testResp = resp;
	 } option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");
}

- (void)testNoToken {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;
	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
	[self.upManager putData:data key:@"hello" token:nil complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	         testInfo = info;
	         testResp = resp;
	 } option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");

	testInfo = nil;
	testResp = nil;
	[self.upManager putData:data key:@"hello" token:@"" complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	         testInfo = info;
	         testResp = resp;
	 } option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");

	testInfo = nil;
	testResp = nil;
	[self.upManager putData:nil key:@"hello" token:nil complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
	         testInfo = info;
	         testResp = resp;
	 } option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");
}

- (void)testNoComplete {
	NSException *e;
	@try {
		[self.upManager putFile:nil key:nil token:nil complete:nil option:nil];
	}
	@catch (NSException *exception)
	{
		e = exception;
	}

	XCTAssert(e != nil, @"Pass");
	XCTAssert([e.name isEqualToString:NSInvalidArgumentException], @"Pass");
}

- (void)testNoKey {
	__block QNResponseInfo *testInfo = nil;
	__block NSDictionary *testResp = nil;
	__block NSString *key = nil;

	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
	[self.upManager putData:data key:nil token:g_token complete: ^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
	         key = k;
	         testInfo = info;
	         testResp = resp;
	 } option:nil];

	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
	NSLog(@"%@", testInfo);
	NSLog(@"%@", testResp);
	XCTAssert(key == nil, @"Pass");
	XCTAssert(testInfo.isOK, @"Pass");
	XCTAssert(testInfo.reqId, @"Pass");
	XCTAssert([@"FgoKnypncpQlV6tTVddq9EL49l4B" isEqualToString: testResp[@"key"]], @"Pass");
}

@end
