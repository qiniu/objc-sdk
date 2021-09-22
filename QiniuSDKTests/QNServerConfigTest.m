//
//  QNServerConfigTest.m
//  QiniuSDK
//
//  Created by yangsen on 2021/9/22.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNServerConfigCache.h"
#import "QNServerConfigMonitor.h"
#import "QNServerConfigSynchronizer.h"
#import <XCTest/XCTest.h>

@interface QNServerConfigTest : XCTestCase

@end

@implementation QNServerConfigTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testServerConfigModel {
    NSString *serverConfigJsonString = @"";
    NSDictionary *serverConfigInfo = [NSJSONSerialization JSONObjectWithData:[serverConfigJsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableLeaves error:nil];
    QNServerConfig *serverConfig = [QNServerConfig config:serverConfigInfo];
    XCTAssertTrue(serverConfig != nil, "server config was nil");
    XCTAssertTrue(serverConfig.ttl > 0, "server config ttl was nil");
    XCTAssertTrue(serverConfig.dnsConfig != nil, "server config dns config was nil");
    XCTAssertTrue(serverConfig.dnsConfig.clearId > 0, "server config dns config clearId was nil");
    XCTAssertTrue(serverConfig.dnsConfig.udpConfig != nil, "server config udp dns config was nil");
    XCTAssertTrue(serverConfig.dnsConfig.udpConfig.enable != nil, "server config udp dns config enable was nil");
    XCTAssertTrue(serverConfig.dnsConfig.udpConfig.ipv4Server != nil, "server config udp dns config ipv4Server was nil");
    XCTAssertTrue(serverConfig.dnsConfig.udpConfig.ipv6Server != nil, "server config udp dns config ipv6Server was nil");
    XCTAssertTrue(serverConfig.dnsConfig.dohConfig != nil, "server config doh dns config was nil");
    XCTAssertTrue(serverConfig.dnsConfig.dohConfig.enable != nil, "server config doh dns config enable was nil");
    XCTAssertTrue(serverConfig.dnsConfig.dohConfig.ipv4Server != nil, "server config doh dns config ipv4Server was nil");
    XCTAssertTrue(serverConfig.dnsConfig.dohConfig.ipv6Server != nil, "server config doh dns config ipv6Server was nil");
    XCTAssertTrue(serverConfig.regionConfig != nil, "server config region config was nil");
    XCTAssertTrue(serverConfig.regionConfig.clearId > 0, "server config region config clearId was nil");
    
    
    NSString *serverUserConfigJsonString = @"";
    NSDictionary *serverUserConfigInfo = [NSJSONSerialization JSONObjectWithData:[serverUserConfigJsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableLeaves error:nil];
    QNServerUserConfig *serverUserConfig = [QNServerUserConfig config:serverUserConfigInfo];
    XCTAssertTrue(serverUserConfig != nil, "server user config was nil");
    XCTAssertTrue(serverUserConfig.ttl > 0, "server user config ttl was nil");
    XCTAssertTrue(serverUserConfig.http3Enable != nil, "server user config http3Enable was nil");
    XCTAssertTrue(serverUserConfig.networkCheckEnable != nil, "server user config networkCheckEnable was nil");
}


@end
