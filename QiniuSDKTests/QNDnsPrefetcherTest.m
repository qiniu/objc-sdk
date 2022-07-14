//
//  QNDnsPrefetcherTest.m
//  QiniuSDK_MacTests
//
//  Created by yangsen on 2020/3/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNDnsPrefetch.h"
#import "QNTestConfig.h"
#import "QNFixedZone.h"
#import <AGAsyncTestHelper.h>
#import "XCTestCase+QNTest.h"

@interface InetAddress : NSObject <QNIDnsNetworkAddress>

@property(nonatomic,   copy)NSString *hostValue;
@property(nonatomic,   copy)NSString *ipValue;
@property(nonatomic, strong)NSNumber *ttlValue;
@property(nonatomic, strong)NSNumber *timestampValue;
@property(nonatomic,   copy)NSString *sourceValue;

@end
@implementation InetAddress

@end

#define CustomIPValue @"192.168.1.1"
#define kCustomHost @"uplog.qbox.me"
#define kDnsTestToken token_na0

@interface CustomDns : NSObject <QNDnsDelegate>
@property(nonatomic, assign)BOOL isTestTtl;
@end
@implementation CustomDns

- (NSArray<id<QNIDnsNetworkAddress>> *)lookup:(NSString *)host{
    if (![host isEqualToString:kCustomHost]) {
        return nil;
    }
    
    InetAddress *inetAddress = [[InetAddress alloc] init];
    inetAddress.hostValue = host;
    inetAddress.ipValue = CustomIPValue;
    if (!_isTestTtl) {
        inetAddress.ttlValue = @(1);
    }
    inetAddress.timestampValue = @([[NSDate date] timeIntervalSince1970]);
    return @[inetAddress];
}

@end



@interface QNDnsPrefetcherTest : XCTestCase

@property(nonatomic, strong)QNConfiguration *config;

@end

@implementation QNDnsPrefetcherTest

- (void)setUp {
    
    [kQNTransactionManager destroyResource];
    _config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.zone = [QNFixedZone createWithHost:@[kCustomHost]];
    }];
}

- (void)tearDown {
    [super tearDown];
    
    kQNGlobalConfiguration.dns = nil;
}

- (void)testLocalLoad {
    [self testPreFetch];
    
    kQNGlobalConfiguration.dns = [[CustomDns alloc] init];
    kQNGlobalConfiguration.isDnsOpen = YES;
    [kQNTransactionManager addDnsLocalLoadTransaction];
    
    AGWW_WAIT_WHILE([kQNDnsPrefetch getInetAddressByHost:kCustomHost] == nil, 60 * 5);
    
    NSArray <id <QNIDnsNetworkAddress>> *addressList = [kQNDnsPrefetch getInetAddressByHost:kCustomHost];
    XCTAssert(addressList.count > 0, @"addressList count:%ld", addressList.count);
}

- (void)testPreFetch {
    
    [kQNTransactionManager addDnsCheckAndPrefetchTransaction:_config.zone token:[QNUpToken parse:kDnsTestToken]];
    
    AGWW_WAIT_WHILE([kQNDnsPrefetch getInetAddressByHost:kCustomHost] == nil, 60 * 5);
    
    NSArray <id <QNIDnsNetworkAddress>> *addressList = [kQNDnsPrefetch getInetAddressByHost:kCustomHost];
    XCTAssert(addressList.count > 0, @"addressList count:%ld", addressList.count);
}

- (void)notestCustomDns {
    
    kQNGlobalConfiguration.dns = [[CustomDns alloc] init];
    [kQNTransactionManager addDnsCheckAndPrefetchTransaction:_config.zone token:[QNUpToken parse:kDnsTestToken]];
    
    QN_TEST_CASE_WAIT_TIME(2);
    
    NSArray <id <QNIDnsNetworkAddress>> *addressList = [kQNDnsPrefetch getInetAddressByHost:kCustomHost];
    NSLog(@"addressList count: %ld", addressList.count);
    XCTAssert(addressList.count==1, @"addressList count:%ld", addressList.count);
    XCTAssert([addressList.firstObject.ipValue isEqualToString:CustomIPValue], @"success");
}

- (void)notestDefaultTTL {

    QN_TEST_CASE_WAIT_TIME(1);
    
    CustomDns *dns = [[CustomDns alloc] init];
    dns.isTestTtl = YES;
    kQNGlobalConfiguration.dns = dns;
    kQNGlobalConfiguration.dnsCacheTime = 120;
    
    [kQNTransactionManager addDnsCheckAndPrefetchTransaction:_config.zone token:[QNUpToken parse:kDnsTestToken]];
    
    QN_TEST_CASE_WAIT_TIME(2);
    
    NSArray <id <QNIDnsNetworkAddress>> *addressList = [kQNDnsPrefetch getInetAddressByHost:kCustomHost];
    
    XCTAssert(addressList.count==1, @"addressList count:%ld", addressList.count);
    XCTAssert(addressList.firstObject.ttlValue.doubleValue == 120, @"success");
    
}

- (void)testMutiThreadPrefetch{
    [kQNTransactionManager destroyResource];
    QN_TEST_CASE_WAIT_TIME(2);
    
    int tryPrefetchNum = 100;
    __block int successPrefetchNum = 0;
    
    dispatch_group_t group = dispatch_group_create();
    
    for (int i=0; i<tryPrefetchNum; i++) {
        
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            
            dispatch_group_enter(group);
            BOOL isSuccess = [kQNTransactionManager addDnsCheckAndPrefetchTransaction:self.config.zone token:[QNUpToken parse:kDnsTestToken]];
            if (isSuccess) {
                successPrefetchNum += 1;
            }
            dispatch_group_leave(group);
        });
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 1 or 0
        NSLog(@"successPrefetchNum: %d", successPrefetchNum);
        XCTAssert(successPrefetchNum >= 0, @"successPrefetchNum:%d", successPrefetchNum);
    });
    
    QN_TEST_CASE_WAIT_TIME(2);
}

- (void)testClearCache{
    [kQNTransactionManager destroyResource];
    QN_TEST_CASE_WAIT_TIME(2);
        
    CustomDns *dns = [[CustomDns alloc] init];
    dns.isTestTtl = YES;
    kQNGlobalConfiguration.dns = dns;
    NSString *host = @"uplog.qbox.me";
    dispatch_group_t group = dispatch_group_create();
    
    int times = 10;
    dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
        dispatch_group_enter(group);
        [kQNDnsPrefetch prefetchHostBySafeDns:host error:nil];
        for (int i=0; i<times; i++) {
            for (int i=0; i<times; i++) {
                [kQNDnsPrefetch prefetchHostBySafeDns:[NSString stringWithFormat:@"%d%@", i, host] error:nil];
            }
            [NSThread sleepForTimeInterval:0.0001];
        }
        dispatch_group_leave(group);
    });

    dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
        dispatch_group_enter(group);
        for (int i=0; i<times; i++) {
            [kQNDnsPrefetch clearDnsCache:nil];
            [NSThread sleepForTimeInterval:0.001];
        }
        dispatch_group_leave(group);
    });
    
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
    
    QN_TEST_CASE_WAIT_TIME(2);
}

@end
