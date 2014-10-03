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
    [_httpManager post:@"http://www.baidu.com" withData:data withParams:nil withHeaders:nil withCompleteBlock:^(QNResponseInfo *info, NSDictionary *resp){
        testInfo = info;
    }withProgressBlock:nil withCancelBlock:nil];
    AGWW_WAIT_WHILE(testInfo==nil, 100.0);
    NSLog(@"%@", testInfo);
    
    XCTAssert(testInfo.reqId == nil, @"Pass");
    
    testInfo = nil;
    
    [_httpManager post:@"http://api.qiniu.com" withData:nil withParams:nil withHeaders:nil withCompleteBlock:^(QNResponseInfo *info, NSDictionary *resp){
        testInfo = info;
    }withProgressBlock:nil withCancelBlock:nil];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.reqId, @"Pass");
}

- (void)testPostFail {
    __block QNResponseInfo *testInfo = nil;
    NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
    [_httpManager post:@"http://1.1.1.1" withData:data withParams:nil withHeaders:nil withCompleteBlock:^(QNResponseInfo *info, NSDictionary *resp){
        testInfo = info;
    }withProgressBlock:nil withCancelBlock:nil];
    AGWW_WAIT_WHILE(testInfo==nil, 100.0);
    NSLog(@"%@", testInfo);
    
    XCTAssert(testInfo.reqId == nil, @"Pass");
    XCTAssert(testInfo.stausCode == -1, @"Pass");
    XCTAssert(testInfo.error.code == -1004, @"Pass");
}

@end
