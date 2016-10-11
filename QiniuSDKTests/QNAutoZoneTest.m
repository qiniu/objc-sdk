//
//  QNAutoZoneTest.m
//  QiniuSDK
//
//  Created by 白顺龙 on 2016/10/11.
//  Copyright © 2016年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNResponseInfo.h"
#import "QNSessionManager.h"

#import "HappyDNS.h"
#import "QNConfiguration.h"

#import "QNTestConfig.h"
#import "QNUpToken.h"

@interface QNAutoZoneTest : XCTestCase
@property QNAutoZone *autozone;


@end

@implementation QNAutoZoneTest

- (void)setUp {
    [super setUp];
    _autozone = [[QNAutoZone alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testHttp{
    QNAutoZone * autozone = [[QNAutoZone alloc] initWithHttps:NO dns:nil];
    QNUpToken* tok = [QNUpToken parse:g_token];
    __block int x = 0;
    __block int c = 0;
    [autozone preQuery:tok on:^(int code) {
        x = 1;
        c = code;
    }];
    AGWW_WAIT_WHILE(x == 0, 100.0);
    XCTAssertEqual(0, c, @"Pass");
}

@end
