//
//  QNUtilTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/3/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNUtils.h"

@interface QNUtilTest : XCTestCase

@end

@implementation QNUtilTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testIPType {

    NSString *testHost = @"host";
    NSString *type = @"";
    NSString *exceptType = @"";
    
    type = [QNUtils getIpType:@"10.10.120.3" host:testHost];
    exceptType = [NSString stringWithFormat:@"%@-10-10", testHost];
    XCTAssertTrue([type isEqualToString:exceptType]);
    
    type = [QNUtils getIpType:@"130.101.120.3" host:testHost];
    exceptType = [NSString stringWithFormat:@"%@-130-101", testHost];
    XCTAssertTrue([type isEqualToString:exceptType]);
    
    
    type = [QNUtils getIpType:@"2000:0000:0000:0000:0001:2345:6789:abcd" host:testHost];
    exceptType = [NSString stringWithFormat:@"%@-ipv6-2000-0000-0000-0000", testHost];
    XCTAssertTrue([type isEqualToString:exceptType]);
    
    type = [QNUtils getIpType:@"2000:0:0:0:0001:2345:6789:abcd" host:testHost];
    exceptType = [NSString stringWithFormat:@"%@-ipv6-2000-0000-0000-0000", testHost];
    XCTAssertTrue([type isEqualToString:exceptType]);
    
    type = [QNUtils getIpType:@"2000::0001:2345:6789:abcd" host:testHost];
    exceptType = [NSString stringWithFormat:@"%@-ipv6-2000-0000-0000-0000", testHost];
    XCTAssertTrue([type isEqualToString:exceptType]);
}


@end
