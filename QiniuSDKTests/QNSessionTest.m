//
//  QNHttpTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/3.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNResponseInfo.h"
#import "QNSessionManager.h"

#import "QNConfiguration.h"

@interface QNSessionTest : XCTestCase
@property QNSessionManager *httpManager;
@end

@implementation QNSessionTest

- (void)setUp {
    [super setUp];
    _httpManager = [[QNSessionManager alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testPost {
    __block QNResponseInfo *testInfo = nil;
    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    [_httpManager post:@"http://www.google.com" withData:data withParams:nil withHeaders:nil withIdentifier:nil withCompleteBlock:^(QNResponseInfo *httpResponseInfo, NSDictionary *respBody) {
//        testInfo = httpResponseInfo;
//    } withProgressBlock:nil withCancelBlock:nil withAccess:nil];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//    NSLog(@"%@", testInfo);

//    XCTAssert(testInfo.reqId == nil, @"response info1:%@", testInfo);

    testInfo = nil;
    [_httpManager post:@"http://up.qiniu.com" withData:data withParams:nil withHeaders:nil withIdentifier:nil withCompleteBlock:^(QNResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        testInfo = httpResponseInfo;
    } withProgressBlock:nil withCancelBlock:nil withAccess:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.reqId, @"response info2:%@", testInfo);
}

//- (void)testProxy {
//    NSDictionary *proxyDict = @{
//        @"HTTPEnable" : [NSNumber numberWithInt:1],
//        (NSString *)kCFStreamPropertyHTTPProxyHost : @"180.101.136.11",
//        (NSString *)kCFStreamPropertyHTTPProxyPort : @80,
//    };
//
//    QNSessionManager *httpManager = [[QNSessionManager alloc] initWithProxy:proxyDict timeout:60 urlConverter:nil];
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    __block QNResponseInfo *testInfo = nil;
//    [httpManager post:@"http://up123.qiniu.com" withData:data withParams:nil withHeaders:nil withIdentifier:nil withCompleteBlock:^(QNResponseInfo *httpResponseInfo, NSDictionary *respBody) {
//        testInfo = httpResponseInfo;
//    } withProgressBlock:nil withCancelBlock:nil withAccess:nil];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//    NSLog(@"%@", testInfo);
//    XCTAssert(testInfo.reqId, @"Pass");
//}

- (void)testUrlConvert {
    QNUrlConvert c = ^NSString *(NSString *url) {
        return [url stringByReplacingOccurrencesOfString:@"upnono" withString:@"up"];
    };

    QNSessionManager *httpManager = [[QNSessionManager alloc] initWithProxy:nil timeout:60 urlConverter:c];
    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    __block QNResponseInfo *testInfo = nil;
    [httpManager post:@"http://upnono.qiniu.com" withData:data withParams:nil withHeaders:nil withIdentifier:nil withCompleteBlock:^(QNResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        testInfo = httpResponseInfo;
    } withProgressBlock:nil withCancelBlock:nil withAccess:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.reqId, @"response info1:%@", testInfo);
    XCTAssert([testInfo.host isEqual:@"up.qiniu.com"], @"response info1:%@", testInfo);
}

//- (void)testPostIp {
//    __block QNResponseInfo *testInfo = nil;
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    QNResolver *resolver = [[QNResolver alloc] initWithAddress:@"114.114.115.115"];
//    QNDnsManager *dns = [[QNDnsManager alloc] init:[NSArray arrayWithObject:resolver] networkInfo:[QNNetworkInfo normal]];
////    [dns putHosts:@"upnonono.qiniu.com" ip:[[QNFixedZone zone0] up:nil].ips[0]];
//    [dns putHosts:@"upnonono.qiniu.com" ip:nil];
//    QNSessionManager *httpManager = [[QNSessionManager alloc] initWithProxy:nil timeout:60 urlConverter:nil dns:dns];
//    [httpManager post:@"http://upnonono.qiniu.com" withData:data withParams:nil withHeaders:nil withCompleteBlock:^(QNResponseInfo *info, NSDictionary *resp) {
//        testInfo = info;
//    }
//        withProgressBlock:nil
//          withCancelBlock:nil
//               withAccess:nil];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//    NSLog(@"%@", testInfo);
//    XCTAssert(testInfo.reqId, @"Pass");
//}

//- (void)testPostNoPort {
//	__block QNResponseInfo *testInfo = nil;
//	QNSessionManager *httpManager = [[QNSessionManager alloc] initWithProxy:nil timeout:60 urlConverter:nil upStatsDropRate:-1 dns:nil];
//	[httpManager post:@"http://up.qiniug.com:12345/" withData:nil withParams:nil withHeaders:nil withStats:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
//	         testInfo = info;
//	 } withProgressBlock:nil withCancelBlock:nil];
//
//	AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//	NSLog(@"%@", testInfo);
//	XCTAssert(testInfo.statusCode < 0, @"Pass");
//}
//
//// travis ci iOS simulator 8.1 failed，其他环境（mac, iOS 9.0）正常，待详细排查
//- (void)testPostHttps {
//    __block QNResponseInfo *testInfo = nil;
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    QNResolver *resolver = [[QNResolver alloc] initWithAddres:@"114.114.115.115"];
//    QNDnsManager *dns = [[QNDnsManager alloc] init:[NSArray arrayWithObject:resolver] networkInfo:[QNNetworkInfo normal]];
//    QNSessionManager *httpManager = [[QNSessionManager alloc] initWithProxy:nil timeout:300 urlConverter:nil upStatsDropRate:-1 dns:dns];
//    [httpManager post:@"https://up.qbox.me" withData:data withParams:nil withHeaders:nil withStats:nil withCompleteBlock: ^(QNResponseInfo *info, NSDictionary *resp) {
//        testInfo = info;
//    } withProgressBlock:nil withCancelBlock:nil];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 300.0);
//    NSLog(@"%@", testInfo);
//    XCTAssert(testInfo.reqId, @"Pass");
//}

@end

#endif
