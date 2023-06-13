//
//  QNConfigurationTest.m
//  QiniuSDK
//
//  Created by yangsen on 2023/5/25.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNConfiguration.h"

@interface QNConfigurationTest : XCTestCase

@end

@implementation QNConfigurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGlobalDefaultConfig {
    QNGlobalConfiguration *cfg = [QNGlobalConfiguration shared];
    cfg.udpDnsIpv4Servers = nil;
    cfg.dohIpv4Servers = nil;
    cfg.connectCheckURLStrings = nil;
    
    XCTAssertTrue([cfg.udpDnsIpv4Servers containsObject:@"8.8.8.8"], @"default udp ipv4 server error");
    XCTAssertTrue([cfg.dohIpv4Servers containsObject:@"https://8.8.8.8/dns-query"], @"default doh ipv4 server error");
    XCTAssertTrue([cfg.connectCheckURLStrings containsObject:@"https://www.qiniu.com"], @"default connect check url error");
}

@end
