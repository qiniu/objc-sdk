//
//  QNPipelineTest.m
//  QiniuSDK
//
//  Created by BaiLong on 2017/7/27.
//  Copyright © 2017年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

@interface QNPipelineTest : XCTestCase

@end

@implementation QNPipelineTest

- (void)testPump1 {
    __block QNHttpResponseInfo *testInfo = nil;
    NSDictionary *dict = @{ @"platform" : @"ios",
                            @"tl" : @1L,
                            @"tf" : @1.5,
                            @"tb" : @YES,
                            @"td" : [NSDate new] };

    QNPipeline *pipe = [[QNPipeline alloc] init:nil];
    [pipe pumpRepo:@"testsdk" event:dict token:@"Pandora le0xKwjp2_9ZGZMkCok7Gko6aG5GnIHValG82deI:yIl-J0zNjJCUii_7jag6-U79DPY=:eyJyZXNvdXJjZSI6Ii92Mi9yZXBvcy90ZXN0c2RrL2RhdGEiLCJleHBpcmVzIjo1MTAxMDQ1Njg0LCJjb250ZW50TUQ1IjoiIiwiY29udGVudFR5cGUiOiJ0ZXh0L3BsYWluIiwiaGVhZGVycyI6IiIsIm1ldGhvZCI6IlBPU1QifQ==" handler:^(QNHttpResponseInfo *info) {
        testInfo = info;
    }];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);

    XCTAssert(testInfo.isOK, @"Pass");
    XCTAssert(testInfo.reqId, @"Pass");
}

- (void)testPump2 {
    __block QNHttpResponseInfo *testInfo = nil;
    NSDictionary *dict = @{ @"platform" : @"ios",
                            @"tl" : @2L,
                            @"tf" : @1.5,
                            @"tb" : @YES,
                            @"td" : [NSDate new] };
    NSArray *arr = @[ dict, dict ];

    QNPipeline *pipe = [[QNPipeline alloc] init:nil];
    [pipe pumpRepo:@"testsdk" events:arr token:@"Pandora le0xKwjp2_9ZGZMkCok7Gko6aG5GnIHValG82deI:yIl-J0zNjJCUii_7jag6-U79DPY=:eyJyZXNvdXJjZSI6Ii92Mi9yZXBvcy90ZXN0c2RrL2RhdGEiLCJleHBpcmVzIjo1MTAxMDQ1Njg0LCJjb250ZW50TUQ1IjoiIiwiY29udGVudFR5cGUiOiJ0ZXh0L3BsYWluIiwiaGVhZGVycyI6IiIsIm1ldGhvZCI6IlBPU1QifQ==" handler:^(QNHttpResponseInfo *info) {
        testInfo = info;
    }];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);

    XCTAssert(testInfo.isOK, @"Pass");
    XCTAssert(testInfo.reqId, @"Pass");
}

@end
