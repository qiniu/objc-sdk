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
    self.upManager = [[QNUploadManager alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUp2 {
    __block QNResponseInfo *testInfo;
    NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
    NSString *token = @"6UOyH0xzsnOF-uKmsHgpi7AhGWdfvI8glyYV3uPg:m-8jeXMWC-4kstLEHEMCfZAZnWc=:eyJkZWFkbGluZSI6MTQyNDY4ODYxOCwic2NvcGUiOiJ0ZXN0MzY5In0=";
    NSError *error = [self.upManager putData:data withKey:@"hello" withToken:token withCompleteBlock: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        if (!info.error) {
            NSLog(@"%@", info.ReqId);
        }
        else {
        }
    } withOption:nil];
    XCTAssert(error==nil, @"Pass");
    AGWW_WAIT_WHILE(testInfo!=nil, 10.0);
    XCTAssert(testInfo.stausCode == 200, @"Pass");
    
    XCTAssert(testInfo.ReqId != nil, @"Pass");
    XCTAssert(YES, @"Pass");
}

@end
