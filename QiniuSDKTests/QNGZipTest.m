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
    NSData *gzip = [NSData qn_gZip:data];
    XCTAssertTrue([data isEqualToData:gzip], "data is not equal to gzip");
    
    NSString *string = @"ABCDEFG";
    data = [string dataUsingEncoding:NSUTF8StringEncoding];
    gzip = [NSData qn_gZip:data];
    
    NSData *gUnzip = [NSData qn_gUnzip:gzip];
    NSString *stringGUnzip =  [[NSString alloc] initWithData:gUnzip encoding:NSUTF8StringEncoding];
    XCTAssertTrue([string isEqualToString:stringGUnzip], "string:%@ is not equal to stringGUnzip:%@", string, stringGUnzip);
    
    NSData *reGUnzip = [NSData qn_gUnzip:gUnzip];
    XCTAssertTrue([gUnzip isEqualToData:reGUnzip], "gUnzip is not equal to reGUnzip");
}


@end
