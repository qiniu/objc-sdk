//
//  QNNetworkCheckManagerTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+QNTest.h"
#import "QNNetworkCheckManager.h"

@interface QNNetworkCheckManagerTest : XCTestCase

@end
@implementation QNNetworkCheckManagerTest

- (void)testGo{
    
    kQNNetworkCheckManager.maxCheckCount = 10;
    
    NSString *host = @"up.qiniu.com";
    NSArray *ipArray = @[@"180.101.136.87", @"180.101.136.88", @"180.101.136.89", @"122.224.95.105",
                         @"115.238.101.32", @"115.238.101.33", @"115.238.101.34", @"115.238.101.35",
                         @"115.238.101.36", @"180.101.136.11", @"180.101.136.31", @"180.101.136.29",
                         @"180.101.136.28", @"180.101.136.12", @"180.101.136.33", @"180.101.136.30",
                         @"180.101.136.32", @"122.224.95.103", @"122.224.95.108", @"180.101.136.86"];
    [kQNNetworkCheckManager preCheckIPNetworkStatus:ipArray host:host];
    
    QN_TEST_CASE_WAIT_TIME(20);
    
    for (NSString *ip in ipArray) {
        QNNetworkCheckStatus status = [kQNNetworkCheckManager getIPNetworkStatus:ip host:host];
        NSString *statusString = @[@"Unknown", @"A", @"B", @"C", @"D"][status];
        NSLog(@"host:%@, ip:%@, status:%@", host, ip, statusString);
    }
    
}

@end
