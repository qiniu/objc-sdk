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
@end

@implementation QNResumeUploadTest

- (void)setUp {
	[super setUp];
	_upManager = [[QNUploadManager alloc] init];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testOneBlock {
//    __block QNResponseInfo *testInfo = nil;
//    NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
//    NSString *token = @"6UOyH0xzsnOF-uKmsHgpi7AhGWdfvI8glyYV3uPg:m-8jeXMWC-4kstLEHEMCfZAZnWc=:eyJkZWFkbGluZSI6MTQyNDY4ODYxOCwic2NvcGUiOiJ0ZXN0MzY5In0=";
//    [self.upManager putData:data withKey:@"hello" withToken:token withCompleteBlock: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
//        testInfo = info;
//         NSLog(@"error %@", info.error);
//        if (!info.error) {
//            NSLog(@"%@", info.reqId);
//        }
//        else {
//        }
//    } withOption:nil];
//    AGWW_WAIT_WHILE(testInfo, 10.0);
//    NSLog(@"%@", testInfo);
//
//    XCTAssert(testInfo.reqId != nil, @"Pass");
}

@end
