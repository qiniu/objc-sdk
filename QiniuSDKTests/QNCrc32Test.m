//
//  QNCrc32Test.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QiniuSDK.h"

@interface QNCrc32Test : XCTestCase

- (void)testData;

@end

@implementation QNCrc32Test


- (void)testData {
    NSData *buffer = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    UInt32 crc = [QNCrc32 data:buffer];
    XCTAssert(crc == 3964322768, @"Pass");
}


@end
