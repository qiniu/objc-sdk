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
    NSString *etag = [QNEtag data:nil];
    XCTAssert([@"Fto5o-5ea0sNMlW_75VgGJCv2AcJ" isEqualToString:etag], @"etag:%@", etag);
}

- (void)testFile5M {
    NSError *error;
    QNTempFile *file = [QNTempFile createTempFileWithSize:5 * 1024 * 1024 identifier:@"5M"];
    NSString *x = [QNEtag file:file.fileUrl.path error:&error];
    XCTAssert([@"ljfceY5osQDM_NJlPaUFlJqQ8POB" isEqualToString:x], @"Pass");
    [file remove];
}

- (void)testFile3M {
    NSError *error;
    QNTempFile *file = [QNTempFile createTempFileWithSize:3 * 1024 * 1024 identifier:@"3M"];
    NSString *x = [QNEtag file:file.fileUrl.path error:&error];
    XCTAssert([@"FtPguFLrJJy4r4LRCzjJDP7wgIZe" isEqualToString:x], @"Pass");
    [file remove];
}

- (void)testData {
    NSData *data = [@"etag" dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"%@", [QNEtag data:data]);
    XCTAssert([@"FpLiADEaVoALPkdb8tJEJyRTXoe_" isEqualToString:[QNEtag data:data]], @"Pass");
}

@end
