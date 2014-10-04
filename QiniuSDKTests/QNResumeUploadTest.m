//
//  QNResumeUploadTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

@interface QNResumeUploadTest : XCTestCase
@property QNUploadManager *upManager;
@property BOOL inTravis;
@end

@implementation QNResumeUploadTest

- (void)setUp {
	[super setUp];
	_upManager = [[QNUploadManager alloc] init];
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
	NSString *travis = [[[NSProcessInfo processInfo]environment]objectForKey:@"QINIU_TEST_ENV"];
	if ([travis isEqualToString:@"travis"]) {
		_inTravis = YES;
	}
#endif
}

- (void)tearDown {
	[super tearDown];
}

- (void)test600k {
}

#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED

- (void)test1M {
}

- (void)test4M {
	if (_inTravis) {
		return;
	}
}

- (void)test8M {
	if (_inTravis) {
		return;
	}
}

#endif
@end
