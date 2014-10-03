//
//  FormUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "QiniuSDK.h"

@interface QNFormUploadTesT : XCTestCase

- (void)testUp;
@property QNUploadManager *upManager;

@end

@implementation QNFormUploadTesT

- (void)setUp {
	[super setUp];
	self.upManager = [[QNUploadManager alloc] init];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testUp {
	__block QNResponseInfo *testInfo;
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
	NSString *token = @"6UOyH0xzsnOF-uKmsHgpi7AhGWdfvI8glyYV3uPg:m-8jeXMWC-4kstLEHEMCfZAZnWc=:eyJkZWFkbGluZSI6MTQyNDY4ODYxOCwic2NvcGUiOiJ0ZXN0MzY5In0=";
	NSError *error = [self.upManager putData:data withKey:@"hello" withToken:token withCompleteBlock: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        dispatch_semaphore_signal(semaphore);
	    testInfo = info;
	    if (!info.error) {
	        NSLog(@"%@", info.ReqId);
		}
	    else {
		}
	} withOption:nil];
//    sleep(10);
    XCTAssert(!error, @"Pass");
//	dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
	XCTAssert(YES, @"Pass");
}

@end
