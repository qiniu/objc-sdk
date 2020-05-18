//
//  FormUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

#import "QNTestConfig.h"

@interface QNFormUploadTest : XCTestCase

@property QNUploadManager *upManager;

@end

@implementation QNFormUploadTest

- (void)setUp {
    [super setUp];
    _upManager = [QNUploadManager sharedInstanceWithConfiguration:nil];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUp {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;

    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"x:foo" : @"bar" } checkCrc:YES cancellationSignal:nil];
    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    [self.upManager putData:data key:@"你好" token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:opt];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    XCTAssert(testInfo.isOK, @"Pass");
    XCTAssert(testInfo.reqId, @"Pass");
}

// upload 100 file and calculate upload success rate
- (void)test100Up {
    NSInteger count = 100;
    __block NSInteger completeCount = 0;
    __block NSInteger successCount = 0;
    for (int i=0; i<count; i++) {
        NSString *taskId = [NSString stringWithFormat:@"test100Up_%d", i];
        [self test100UpTask:taskId complete:^(BOOL isSuccess) {
            @synchronized (self) {
                if (isSuccess) {
                    successCount += 1;
                }
                completeCount += 1;
                NSLog(@"upload file: test100Up_%d", i);
            }
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != count, 100.0);
    
    CGFloat successRate = successCount * 1.0 / count;
    NSLog(@"successCount: %td", successCount);
    NSLog(@"successRate: %lf", successRate);
    XCTAssert(completeCount == count, @"Pass");
}

- (void)test100UpTask:(NSString *)taskId complete:(void(^)(BOOL isSuccess))complete{
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.timeoutInterval = 5;
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc]initWithConfiguration:config];
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"x:foo" : @"bar" } checkCrc:YES cancellationSignal:nil];
    NSMutableString *contentString = [NSMutableString string];
    NSString *word = @"Hello, World!";
    while (contentString.length < 1024) {
        [contentString appendString:word];
    }
    NSData *data = [[contentString copy] dataUsingEncoding:NSUTF8StringEncoding];
    [upManager putData:data key:taskId token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        if (info.isOK && info.reqId) {
            complete(YES);
        } else {
            NSLog(@"upload failed. response info is: %@",info);
            complete(NO);
        }
    } option:opt];
}


// travis ci iOS simulator 8.1 failed，其他环境（mac, iOS 9.0）正常，待详细排查
//- (void)testHttpsUp {
//    __block QNResponseInfo *testInfo = nil;
//    __block NSDictionary *testResp = nil;
//
//    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"x:foo":@"bar" } checkCrc:YES cancellationSignal:nil];
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
//        QNServiceAddress *s = [[QNServiceAddress alloc] init:@"https://uptemp.qbox.me" ips:nil];
//        builder.zone = [[QNZone alloc] initWithUp:s upBackup:nil];
//    }];
//    QNUploadManager *upManager = [[QNUploadManager alloc]initWithConfiguration:config];
//    [upManager putData:data key:@"你好" token:g_token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
//        testInfo = info;
//        testResp = resp;
//    } option:opt];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//    NSLog(@"%@", testInfo);
//    NSLog(@"%@", testResp);
//    XCTAssert(testInfo.isOK, @"Pass");
//    XCTAssert(testInfo.reqId, @"Pass");
//}

- (void)testUpUnAuth {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *token = @"noauth";
    [self.upManager putData:data key:@"hello" token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == kQNInvalidToken, @"Pass");
    XCTAssert(testInfo.reqId == nil, @"Pass");
}

- (void)testNoData {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    NSString *token = @"noauth";
    [self.upManager putData:nil key:@"hello" token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");
}

- (void)testNoFile {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    NSString *token = @"noauth";
    [self.upManager putFile:nil key:@"hello" token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");
}

- (void)testNoToken {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    [self.upManager putData:data key:@"hello" token:nil complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");

    testInfo = nil;
    testResp = nil;
    [self.upManager putData:data key:@"hello" token:@"" complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");

    testInfo = nil;
    testResp = nil;
    [self.upManager putData:nil key:@"hello" token:nil complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    XCTAssert(testInfo.statusCode == kQNInvalidArgument, @"Pass");
}

- (void)testNoComplete {
    NSException *e;
    @try {
        [self.upManager putFile:nil key:nil token:nil complete:nil option:nil];
    }
    @catch (NSException *exception) {
        e = exception;
    }

    XCTAssert(e != nil, @"Pass");
    XCTAssert([e.name isEqualToString:NSInvalidArgumentException], @"Pass");
}

- (void)testNoKey {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    __block NSString *key = nil;

    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    [self.upManager putData:data key:nil token:g_token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
        key = k;
        testInfo = info;
        testResp = resp;
    }
                     option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    XCTAssert(key == nil, @"Pass");
    XCTAssert(testInfo.isOK, @"Pass");
    XCTAssert(testInfo.reqId, @"Pass");
    XCTAssert([@"FgoKnypncpQlV6tTVddq9EL49l4B" isEqualToString:testResp[@"key"]], @"Pass");
}

//- (void)testProxy {
//    __block QNResponseInfo *testInfo = nil;
//    __block NSDictionary *testResp = nil;
//    __block NSString *key = nil;
//
//    NSDictionary *proxyDict = @{
//        @"HTTPEnable" : [NSNumber numberWithInt:1],
//        (NSString *)kCFStreamPropertyHTTPProxyHost : @"180.101.136.11",
//        (NSString *)kCFStreamPropertyHTTPProxyPort : @80,
//    };
//
//    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
//        builder.proxy = proxyDict;
//        NSArray *upList = [[NSArray alloc] initWithObjects:@"upnono.qiniu.com", @"upnono.qiniu.com", nil];
//        builder.useHttps = NO;
//        builder.zone = [[QNFixedZone alloc] initWithupDomainList:upList];
//    }];
//
//    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
//
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    [upManager putData:data key:nil token:g_token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
//        key = k;
//        testInfo = info;
//        testResp = resp;
//    }
//                option:nil];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//    NSLog(@"%@", testInfo);
//    NSLog(@"%@", testResp);
//    XCTAssert(key == nil, @"Pass");
//    XCTAssert(testInfo.isOK, @"Pass");
//    XCTAssert(testInfo.reqId, @"Pass");
//    XCTAssert([@"FgoKnypncpQlV6tTVddq9EL49l4B" isEqualToString:testResp[@"key"]], @"Pass");
//}

- (void)testUrlConvert {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    __block NSString *key = nil;

    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.converter = ^NSString *(NSString *url) {
            return [url stringByReplacingOccurrencesOfString:@"upnono" withString:@"up"];
        };
        NSArray *upList = [[NSArray alloc] initWithObjects:@"upnono.qiniu.com", @"upnono.qiniu.com", nil];
        builder.useHttps = NO;
        builder.zone = [[QNFixedZone alloc] initWithupDomainList:upList];
    }];

    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    [upManager putData:data key:nil token:g_token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
        key = k;
        testInfo = info;
        testResp = resp;
    }
                option:nil];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    XCTAssert(key == nil, @"Pass");
    XCTAssert(testInfo.isOK, @"Pass");
    XCTAssert(testInfo.reqId, @"Pass");
    XCTAssert([testInfo.host isEqual:@"up.qiniu.com"], @"Pass");
    XCTAssert([@"FgoKnypncpQlV6tTVddq9EL49l4B" isEqualToString:testResp[@"key"]], @"Pass");
}

//- (void)testDnsHosts {
//    __block QNResponseInfo *testInfo = nil;
//    __block NSDictionary *testResp = nil;
//    __block NSString *key = nil;
//    QNResolver *resolver = [[QNResolver alloc] initWithAddress:@"114.114.115.115"];
//    QNDnsManager *dns = [[QNDnsManager alloc] init:[NSArray arrayWithObject:resolver] networkInfo:[QNNetworkInfo normal]];
//    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
//        NSArray *ips = [[QNFixedZone zone0] up:nil].ips;
//        QNServiceAddress *s1 = [[QNServiceAddress alloc] init:@"http://uphosttest.qiniu.com" ips:ips];
//        QNServiceAddress *s2 = [[QNServiceAddress alloc] init:@"http://uphosttestbak.qiniu.com" ips:ips];
//        builder.zone = [[QNFixedZone alloc] initWithUp:s1 upBackup:s2];
//        builder.dns = dns;
//    }];
//
//    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
//
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    [upManager putData:data key:nil token:g_token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
//        key = k;
//        testInfo = info;
//        testResp = resp;
//    }
//                option:nil];
//
//    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
//    NSLog(@"%@", testInfo);
//    NSLog(@"%@", testResp);
//    XCTAssert(key == nil, @"Pass");
//    XCTAssert(testInfo.isOK, @"Pass");
//    XCTAssert(testInfo.reqId, @"Pass");
//    XCTAssert([testInfo.host isEqual:@"uphosttest.qiniu.com"], @"Pass");
//    XCTAssert([@"FgoKnypncpQlV6tTVddq9EL49l4B" isEqualToString:testResp[@"key"]], @"Pass");
//}

- (void)test0sizeData {
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;

    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"x:foo" : @"bar" } checkCrc:YES cancellationSignal:nil];
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    [self.upManager putData:data key:@"你好" token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    }
                     option:opt];

    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    XCTAssert(testInfo.statusCode == kQNZeroDataSize, @"Pass");
}

@end
