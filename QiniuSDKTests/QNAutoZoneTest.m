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

#import "QNAutoZone.h"
#import "QNConfiguration.h"
#import "QNZoneInfo.h"
#import "QNTestConfig.h"
#import "QNUpToken.h"
#import "QNConfig.h"

@interface QNAutoZoneTest : XCTestCase
@property QNAutoZone* autozone;

@end

@implementation QNAutoZoneTest

- (void)setUp {
    [super setUp];
    _autozone = [[QNAutoZone alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testAutoZone {
    QNAutoZone* autoZone = [[QNAutoZone alloc] init];
    QNUpToken* tok = [QNUpToken parse:token_na0];
    __block int x = 0;
    __block int c = 0;
    [autoZone preQuery:tok on:^(int code, QNResponseInfo *info, QNUploadRegionRequestMetrics *metrics) {
        x = 1;
        c = code;
    }];
    AGWW_WAIT_WHILE(x == 0, 100.0);
    XCTAssertEqual(0, c, @"c: %d", c);
}

- (void)testSetUcHosts02 {
    QNAutoZone* autoZone = [QNAutoZone zoneWithUcHosts:@[kQNPreQueryHost02]];
    QNUpToken* tok = [QNUpToken parse:token_na0];
    __block int x = 0;
    __block int c = 0;
    [autoZone preQuery:tok on:^(int code, QNResponseInfo *info, QNUploadRegionRequestMetrics *metrics) {
        x = 1;
        c = code;
    }];
    AGWW_WAIT_WHILE(x == 0, 100.0);
    XCTAssertEqual(0, c, @"c: %d", c);
}

- (void)testClearAutoZoneCache {
    QNAutoZone *autoZone = [[QNAutoZone alloc] init];
    QNUpToken* tok = [QNUpToken parse:token_na0];
    __block int x = 0;
    __block int c = 0;
    [autoZone preQuery:tok on:^(int code, QNResponseInfo *info, QNUploadRegionRequestMetrics *metrics) {
        x = 1;
        c = code;
    }];
    AGWW_WAIT_WHILE(x == 0, 100.0);
    XCTAssertEqual(0, c, @"c: %d", c);
    
    QNZonesInfo *info = [autoZone getZonesInfoWithToken:tok];
    XCTAssertTrue(info != nil , @"info is nil");
    XCTAssertTrue(!info.isTemporary , @"info is temporary");
    
    [QNAutoZone clearCache];
    
    info = [autoZone getZonesInfoWithToken:tok];
    XCTAssertTrue(info != nil , @"after clear: info is nil");
    XCTAssertTrue(info.isTemporary , @"after clear: info is not temporary");
}

- (void)testHttp {
    QNAutoZone* autoZone = [[QNAutoZone alloc] init];
    QNUpToken* tok = [QNUpToken parse:token_na0];
    __block int x = 0;
    __block int c = 0;
    [autoZone preQuery:tok on:^(int code, QNResponseInfo *info, QNUploadRegionRequestMetrics *metrics) {
        x = 1;
        c = code;
    }];
    AGWW_WAIT_WHILE(x == 0, 100.0);
    XCTAssertEqual(0, c, @"c: %d", c);
}

- (void)testMutiHttp{
    for (int i=0; i<5; i++) {
        [self testHttp];
    }
}

@end
