//
//  QNNetworkCheckManagerTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+QNTest.h"
#import "QNConfiguration.h"
#import "QNNetworkCheckManager.h"

@interface QNNetworkCheckManagerTest : XCTestCase

@end
@implementation QNNetworkCheckManagerTest

- (void)testCheckCount{
    
    kQNGlobalConfiguration.maxCheckCount = 100;
    
    NSString *host = @"up.qiniu.com";
    NSArray *ipArray = @[@"180.101.136.87", @"180.101.136.88", @"180.101.136.89", @"122.224.95.105",
                         @"115.238.101.32", @"115.238.101.33", @"115.238.101.34", @"115.238.101.35",
                         @"115.238.101.36", @"180.101.136.11", @"180.101.136.31", @"180.101.136.29",
                         @"180.101.136.28", @"180.101.136.12", @"180.101.136.33", @"180.101.136.30",
                         @"180.101.136.32", @"122.224.95.103", @"122.224.95.108", @"180.101.136.86"];
    [kQNTransactionManager addCheckSomeIPNetworkStatusTransaction:ipArray host:host];
    
    [self getIPListNetworkStatus:@[@"180.101.136.87"] host:host];
    
    QN_TEST_CASE_WAIT_TIME(20);
    
    [self getIPListNetworkStatus:ipArray host:host];
}

- (void)testIPArray{
    
    kQNGlobalConfiguration.maxCheckCount = 10;
    
    NSString *host = @"up.qiniu.com";
    NSMutableArray *ipArray = [@[@"180.101.136.87", @"180.101.136.88", @"180.101.136.89", @"122.224.95.105",
                                 @"115.238.101.32", @"115.238.101.33", @"115.238.101.34", @"115.238.101.35",
                                 @"115.238.101.36", @"180.101.136.11", @"180.101.136.31", @"180.101.136.29",
                                 @"180.101.136.28", @"180.101.136.12", @"180.101.136.33", @"180.101.136.30",
                                 @"180.101.136.32", @"122.224.95.103", @"122.224.95.108", @"180.101.136.86",
                                 @"183.101.136.32", @"123.224.95.103", @"123.224.95.108", @"183.101.136.86"] mutableCopy];
    
    for (int i=0; i<5; i++) {
        [ipArray addObjectsFromArray:[ipArray copy]];
    }
    
    [kQNTransactionManager addCheckSomeIPNetworkStatusTransaction:ipArray host:host];
    
    [self getIPListNetworkStatus:@[@"180.101.136.87"] host:host];
    
    QN_TEST_CASE_WAIT_TIME(30);
    
    [self getIPListNetworkStatus:ipArray host:host];
}

- (void)testMaxTime{
    
    kQNGlobalConfiguration.maxCheckTime = 5;
    kQNGlobalConfiguration.maxCheckCount = 3;
    
    NSString *host = @"up.qiniu.com";
    NSMutableArray *ipArray = [@[@"183.101.136.32", @"123.224.95.103", @"123.224.95.108", @"183.101.136.86"] mutableCopy];
    
    [kQNTransactionManager addCheckSomeIPNetworkStatusTransaction:ipArray host:host];
    
    [self getIPListNetworkStatus:@[@"180.101.136.87"] host:host];
    
    QN_TEST_CASE_WAIT_TIME(17);
    
    [self getIPListNetworkStatus:ipArray host:host];
}


- (void)getIPListNetworkStatus:(NSArray *)ipArray host:(NSString *)host{
    for (NSString *ip in ipArray) {
        QNNetworkCheckStatus status = [kQNNetworkCheckManager getIPNetworkStatus:ip host:host];
        NSString *statusString = @[@"A", @"B", @"C", @"D", @"Unknown"][status];
        NSLog(@"host:%@, ip:%@, status:%@", host, ip, statusString);
    }
}

@end
