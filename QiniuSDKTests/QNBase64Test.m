//
//  QNBase64Test.m
//  QiniuSDK
//
//  Created by bailong on 14/9/30.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QiniuSDK.h"
#import <XCTest/XCTest.h>

@interface QNBase64Test : XCTestCase

@end

@implementation QNBase64Test

- (void)testEncode {
    // This is an example of a functional test case.
    NSString *source = @"你好/+=";
    NSString *encode = [QNUrlSafeBase64 encodeString:source];
    XCTAssert([encode isEqual:@"5L2g5aW9Lys9"], @"encode: %@", encode);
}

@end



