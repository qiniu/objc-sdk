//
//  QNDnsTest.m
//  QiniuSDK
//
//  Created by bailong on 15/1/3.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "QNDns.h"

@interface QNDnsTest : XCTestCase

@end

@implementation QNDnsTest

//- (void)testQiniu {
//	NSString *host = @"qiniu.com";
//	NSString *ip = [[QNDns getAddresses:host] objectAtIndex:0];
//	XCTAssert(ip != nil, @"Pass");
//	NSLog(@"dns result %@", ip);
//}

- (void)testNoHost {
	NSString *nohost = @"nodns.qiniu.com";
	NSArray *noip = [QNDns getAddresses:nohost];
	XCTAssert(noip.count == 0, @"Pass");
	NSLog(@"dns result %@", noip);
}

@end
