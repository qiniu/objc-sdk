//
//  QNGZipTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/8/12.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSData+QNGZip.h"

@interface QNGZipTest : XCTestCase

@end

@implementation QNGZipTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGZip {
    
    NSData *data = [NSData data];
    NSData *gzip = [data qn_gZip];
    XCTAssertTrue([gzip isEqualToData:gzip], "pass");
    
    NSString *string = @"ABCDEFG";
    data = [string dataUsingEncoding:NSUTF8StringEncoding];
    gzip = [data qn_gZip];
    
    NSData *gUnzip =  [gzip qn_gUnzip];
    NSString *stringGUnzip =  [[NSString alloc] initWithData:gUnzip encoding:NSUTF8StringEncoding];
    XCTAssertTrue([string isEqualToString:stringGUnzip], "pass");
    
    NSData *reGUnzip =  [gzip qn_gZip];
    XCTAssertTrue([gzip isEqualToData:reGUnzip], "pass");
}


@end
