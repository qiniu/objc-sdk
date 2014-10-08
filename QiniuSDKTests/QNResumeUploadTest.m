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

#import "QNTestConfig.h"
#import "QNTempFile.h"

@interface QNResumeUploadTest : XCTestCase
@property QNUploadManager *upManager;
@property BOOL inTravis;
@end

@implementation QNResumeUploadTest

- (void)setUp {
	[super setUp];
	_upManager = [[QNUploadManager alloc] init];
#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
	NSString *travis = [[[NSProcessInfo processInfo]environment]objectForKey:@"QINIU_TEST_ENV"];
	if ([travis isEqualToString:@"travis"]) {
		_inTravis = YES;
	}
#endif
}

- (void)tearDown {
	[super tearDown];
}

- (void)template:(int)size {
	NSURL *tempFile = [QNTempFile createTempfileWithSize:size * 1024];
	NSString *keyUp = [NSString stringWithFormat:@"%dk", size];
	__block NSString *key = nil;
	__block QNResponseInfo *info = nil;
	QNUploadOption *opt = [[QNUploadOption alloc] initWithProgessHandler: ^(NSString *key, float percent) {
	    NSLog(@"progress %f", percent);
	}

	    ];
	[_upManager putFile:tempFile.path key:keyUp token:g_token complete: ^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
	    key = k;
	    info = i;
	} option:opt];
	AGWW_WAIT_WHILE(key == nil, 60 * 30);
	NSLog(@"info %@", info);
	XCTAssert(info.stausCode == 200, @"Pass");
	XCTAssert(info.reqId, @"Pass");
	XCTAssert([keyUp isEqualToString:key], @"Pass");

	[QNTempFile removeTempfile:tempFile];
}

- (void)test600k {
	[self template:600];
}

#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED

- (void)test1M {
	if (_inTravis) {
		return;
	}
	[self template:1024];
}

- (void)test4M {
	if (_inTravis) {
		return;
	}
	[self template:4 * 1024];
}

- (void)test8M {
	if (_inTravis) {
		return;
	}
	[self template:8 * 1024 + 1];
}

#endif
@end
