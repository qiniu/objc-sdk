//
//  QNBase64Test.m
//  QiniuSDK
//
//  Created by bailong on 14/9/30.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QiniuSDK.h"

@interface QNBase64Test : XCTestCase

@end

@implementation QNBase64Test

- (void)testEncode {
	// This is an example of a functional test case.
	NSString *source = @"你好/+=";

	XCTAssert([[QNBase64 encodeString:source] isEqual:@"5L2g5aW9Lys9"], @"Pass");
}

@end
