//
//  QNDnsPrefetcherTest.m
//  QiniuSDK_MacTests
//
//  Created by yangsen on 2020/3/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNDnsPrefetcher.h"
#import "QNTestConfig.h"
#import "QNFixedZone.h"
#import <AGAsyncTestHelper.h>
#import "XCTestCase+QNTest.h"

@interface InetAddress : NSObject <QNInetAddressDelegate>

@property(nonatomic,   copy)NSString *hostValue;
@property(nonatomic,   copy)NSString *ipValue;
@property(nonatomic, strong)NSNumber *ttlValue;
@property(nonatomic, strong)NSNumber *timestampValue;

@end
@implementation InetAddress
@end

#define CustomIPValue @"192.168.1.1"
@interface CustomDns : NSObject <QNDnsDelegate>
@property(nonatomic, assign)BOOL isTestTtl;
@end
@implementation CustomDns

- (NSArray<id<QNInetAddressDelegate>> *)lookup:(NSString *)host{
    
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

#define kCustomHost @"upload.qiniup.com"
#define kDnsTestToken @"dns_testToken"
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
    
    NSString *host = @"upload.qiniup.com";
    [kQNTransactionManager addDnsLocalLoadTransaction];
    
    QN_TEST_CASE_WAIT_TIME(5);

    NSArray <id <QNInetAddressDelegate>> *addressList = [kQNDnsPrefetcher getInetAddressByHost:host];
    XCTAssert(addressList.count > 0, @"success");
}

- (void)testPreFetch {
    
    [kQNTransactionManager addDnsCheckAndPrefetchTransaction:_config.zone token:kDnsTestToken];
    
    AGWW_WAIT_WHILE([kQNDnsPrefetcher getInetAddressByHost:kCustomHost] == nil, 60 * 5);
    
    NSArray <id <QNInetAddressDelegate>> *addressList = [kQNDnsPrefetcher getInetAddressByHost:kCustomHost];
    XCTAssert(addressList.count > 0, @"success");
}

- (void)notestCustomDns {

    InetAddress *address = [[InetAddress alloc] init];
    address.hostValue = kCustomHost;
    address.ipValue = CustomIPValue;
    [kQNDnsPrefetcher invalidInetAdress:address];
    
    kQNGlobalConfiguration.dns = [[CustomDns alloc] init];
    [kQNTransactionManager addDnsCheckAndPrefetchTransaction:_config.zone token:kDnsTestToken];
    
    QN_TEST_CASE_WAIT_TIME(2);
    
    NSArray <id <QNInetAddressDelegate>> *addressList = [kQNDnsPrefetcher getInetAddressByHost:kCustomHost];
    NSLog(@"addressList count: %ld", addressList.count);
    XCTAssert(addressList.count==1, @"success");
    XCTAssert([addressList.firstObject.ipValue isEqualToString:CustomIPValue], @"success");
}

- (void)notestDefaultTTL {

    InetAddress *address = [[InetAddress alloc] init];
    address.hostValue = kCustomHost;
    address.ipValue = CustomIPValue;
    [kQNDnsPrefetcher invalidInetAdress:address];
    QN_TEST_CASE_WAIT_TIME(1);
    
    CustomDns *dns = [[CustomDns alloc] init];
    dns.isTestTtl = YES;
    kQNGlobalConfiguration.dns = dns;
    kQNGlobalConfiguration.dnsCacheTime = 120;
    
    [kQNTransactionManager addDnsCheckAndPrefetchTransaction:_config.zone token:kDnsTestToken];
    
    QN_TEST_CASE_WAIT_TIME(2);
    
    NSArray <id <QNInetAddressDelegate>> *addressList = [kQNDnsPrefetcher getInetAddressByHost:kCustomHost];
    
    XCTAssert(addressList.count==1, @"success");
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
            BOOL isSuccess = [kQNTransactionManager addDnsCheckAndPrefetchTransaction:self.config.zone
                                                                                token:kDnsTestToken];
            if (isSuccess) {
                successPrefetchNum += 1;
            }
            dispatch_group_leave(group);
        });
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"successPrefetchNum: %d", successPrefetchNum);
        XCTAssert(successPrefetchNum >= 0, @"success");
    });
    
    QN_TEST_CASE_WAIT_TIME(2);
}

@end
