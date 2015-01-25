//
//  QNHttpTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/3.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNSessionManager.h"
#import "QNResponseInfo.h"

@interface QNSessionTest : XCTestCase
@property QNSessionManager *httpManager;
@end

@implementation QNSessionTest

- (void)setUp {
    [super setUp];
    _httpManager = [[QNSessionManager alloc] initWithProxy:nil];
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
    
    [_httpManager post:@"http://up.qiniu.com" withData:data withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
        testInfo = info;
    } withProgressBlock:nil withCancelBlock:nil];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.reqId, @"Pass");
    
    testInfo = nil;
    [_httpManager post:@"http://httpbin.org/status/500" withData:data withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
        testInfo = info;
    } withProgressBlock:nil withCancelBlock:nil];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == 500, @"Pass");
    XCTAssert(testInfo.error != nil, @"Pass");
    
    testInfo = nil;
    [_httpManager post:@"http://httpbin.org/status/418" withData:data withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
        testInfo = info;
    } withProgressBlock:nil withCancelBlock:nil];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == 418, @"Pass");
    XCTAssert(testInfo.error != nil, @"Pass");
    
    testInfo = nil;
    [_httpManager post:@"http://httpbin.org/status/200" withData:data withParams:nil withHeaders:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
        testInfo = info;
    } withProgressBlock:nil withCancelBlock:nil];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == 200, @"Pass");
    XCTAssert(!testInfo.isOK, @"Pass");
    XCTAssert(testInfo.error != nil, @"Pass");
}

@end

#endif