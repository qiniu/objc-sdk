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
    
}

@end
