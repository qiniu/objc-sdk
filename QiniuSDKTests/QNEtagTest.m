//
//  QNEtagTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "QNEtag.h"
#import "QNTempFile.h"

@interface QNEtagTest : XCTestCase

@end

@implementation QNEtagTest

- (void)testEtagZero {
	XCTAssert([@"Fto5o-5ea0sNMlW_75VgGJCv2AcJ" isEqualToString:[QNEtag data:nil]], @"Pass");
}

- (void)testFile {
	NSError *error;
	NSURL *file = [QNTempFile createTempfileWithSize:5 * 1024 * 1024];
	NSString *x = [QNEtag file:[file relativePath] error:&error];
	NSLog(@"%@", x);
	XCTAssert([@"lrMhp7oU8rzWSRlmUeGJ73Q2pVa-" isEqualToString:x], @"Pass");
	[QNTempFile removeTempfile:file];
}

- (void)testData {
	NSData *data = [@"etag" dataUsingEncoding:NSUTF8StringEncoding];
	NSLog(@"%@", [QNEtag data:data]);
	XCTAssert([@"FpLiADEaVoALPkdb8tJEJyRTXoe_" isEqualToString:[QNEtag data:data]], @"Pass");
}

@end
