//
//  QNUpTokenTest.m
//  QiniuSDK
//
//  Created by bailong on 15/6/7.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "QNTestConfig.h"
#import "QNUpToken.h"


@interface QNUpTokenTest : XCTestCase

@end

@implementation QNUpTokenTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//public void testReturnUrl() {
//    UpToken t = UpToken.parse("QWYn5TFQsLLU1pL5MFEmX3s5DmHdUThav9WyOWOm:1jLiztn4plVyeB8Hie1ryO5z9uo=:eyJzY29wZSI6InB5c2RrIiwiZGVhZGxpbmUiOjE0MzM0ODM5MzYsInJldHVyblVybCI6Imh0dHA6Ly8xMjcuMC4wLjEvIn0=");
//    Assert.assertTrue(t.hasReturnUrl());
//}

- (void)testRight {
    QNUpToken *t = [QNUpToken parse:token_na0];
    // This is an example of a functional test case.
    XCTAssert(t != nil, @"token was nil");
    XCTAssert(t.isValid, @"token was invalid");
    XCTAssert([t isValidForDuration:5*60], @"token was invalid for 5*60");
    XCTAssert([t isValidBeforeDate:[NSDate date]], @"token was invalid");
    XCTAssert(!t.hasReturnUrl, @"token has return url");
}

- (void)testEmpty {
    QNUpToken *t = [QNUpToken parse:nil];
    // This is an example of a functional test case.
    XCTAssert(t == nil, @"token was not nil");

    t = [QNUpToken parse:@""];
    // This is an example of a functional test case.
    XCTAssert(t == nil, @"token was not nil");
}

- (void)testReturnUrl {
    QNUpToken *t = [QNUpToken parse:@"QWYn5TFQsLLU1pL5MFEmX3s5DmHdUThav9WyOWOm:1jLiztn4plVyeB8Hie1ryO5z9uo=:eyJzY29wZSI6InB5c2RrIiwiZGVhZGxpbmUiOjE0MzM0ODM5MzYsInJldHVyblVybCI6Imh0dHA6Ly8xMjcuMC4wLjEvIn0="];
    // This is an example of a functional test case.
    XCTAssert(t.hasReturnUrl, @"token has return url");
}

- (void)testScopeNull {
    QNUpToken *t = [QNUpToken parse:@"k4MXrVJes7RoS7N7teQDfkVqDDXqNOZq5BOfjzPn:MDllYmMxYTkyNjIxZTg0N2NjYTUwNDg0MGIyOWQxYjhjMTBlZTc0Ngo=:eyJzY29wZSI6bnVsbCwiZGVhZGxpbmUiOjE1MTM3Njg3ODl9Cg=="];
    // This is an example of a functional test case.
    XCTAssert([t.bucket isEqualToString:@""], @"token bucket:%@", t.bucket);
}

@end
