//
//  FormUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadFlowTest.h"

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNFormUploadTest : QNUploadFlowTest

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

- (void)testSwitchRegion {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@5, @50, @200, @500, @800, @1000, @2000, @3000, @4000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"form_switch_region_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeSwitchRegionTestWithFile:tempFile key:key config:config option:nil];
    }
}

- (void)testCancel {
    float cancelPercent = 0.02;
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.putThreshold = 100*1024*1024;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@30000]; // 网速太快
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"form_cancel_%@k_%@", size, [NSDate date]];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeCancelTest:cancelPercent * size.longLongValue * 1024 tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testHttp {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useHttps = NO;
    }];
    NSArray *sizeArray = @[@5, @50, @200, @500, @800, @1000, @2000, @3000, @4000];
    @autoreleasepool {
        for (NSNumber *size in sizeArray) {
            NSString *key = [NSString stringWithFormat:@"form_http_%@k", size];
            QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
            [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:config option:nil];
        }
    }
}

- (void)testHttpsV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@5, @50, @200, @500, @800, @1000, @2000, @3000, @4000];
    @autoreleasepool {
        for (NSNumber *size in sizeArray) {
            NSString *key = [NSString stringWithFormat:@"form_https_%@k", size];
            QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
            [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:config option:nil];
        }
    }
}

- (void)testSmall {
    NSString *key = @"你好:";
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:@"text/plain" progressHandler:nil params:@{ @"x:foo" : @"bar" } checkCrc:YES cancellationSignal:nil];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1 identifier:key];
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:nil option:opt];
}

// upload 100 file and calculate upload success rate
- (void)test100Up {
    NSInteger count = 100;
    for (int i=0; i<count; i++) {
        NSString *key = [NSString stringWithFormat:@"form_100_up_%dk", i];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1024 identifier:key];
        [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:nil option:nil];
    }
}


- (void)testUpUnAuth {

    NSString *key = @"form_no_auth";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1 identifier:key];
    NSString *token = @"noAuth";
    [self allFileTypeUploadAndAssertResult:kQNInvalidToken tempFile:tempFile token:token key:@"form_no_auth" config:nil option:nil];
}

- (void)testNoData {
    [self allFileTypeUploadAndAssertResult:kQNZeroDataSize tempFile:nil key:@"form_no_data" config:nil option:nil];
}

- (void)testNoFile {
    [self allFileTypeUploadAndAssertResult:kQNZeroDataSize tempFile:nil key:@"form_no_file" config:nil option:nil];
}

- (void)testNoToken {
    NSString *key = @"form_no_token";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1024 identifier:key];
    tempFile.canRemove = NO;
    
    [self allFileTypeUploadAndAssertResult:kQNInvalidToken tempFile:tempFile token:nil key:key config:nil option:nil];

    [self allFileTypeUploadAndAssertResult:kQNInvalidToken tempFile:tempFile token:@"" key:key config:nil option:nil];
    
    tempFile.canRemove = YES;
    [self allFileTypeUploadAndAssertResult:kQNInvalidToken tempFile:tempFile token:@"ABC" key:key config:nil option:nil];
}

- (void)testNoComplete {
    NSException *e;
    @try {
        QNUploadManager *upManager = [QNUploadManager sharedInstanceWithConfiguration:nil];
        [upManager putFile:nil key:nil token:nil complete:nil option:nil];
    }
    @catch (NSException *exception) {
        e = exception;
    }

    XCTAssert(e != nil, @"Pass");
    XCTAssert([e.name isEqualToString:NSInvalidArgumentException], @"Pass");
}

- (void)testNoKey {
    
    NSString *key = @"form_no_key";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1024 identifier:key];
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:nil config:nil option:nil];
}


- (void)testCustomParam {
    
    NSDictionary *userParam = @{@"x:foo" : @"foo_value",
                                @"x:bar" : @"bar_value"};
    NSDictionary *metaParam = @{@"aaaa" : @"meta_value_1",
                                @"x-qn-meta-key-2" : @"meta_value_2"};
    QNUploadOption *option = [[QNUploadOption alloc] initWithMime:nil
                                                  progressHandler:nil
                                                           params:userParam
                                                   metaDataParams:metaParam
                                                         checkCrc:YES
                                               cancellationSignal:nil];
    NSString *file_key = @"form_custom_param_file";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1024 identifier:file_key];
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:file_key config:nil option:option];
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
//        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
//    }];
//
//    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
//
//    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
//    [upManager putData:data key:nil token:token_na0 complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
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
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.converter = ^NSString *(NSString *url) {
            return [url stringByReplacingOccurrencesOfString:@"upnono" withString:@"up"];
        };
        NSArray *upList = [[NSArray alloc] initWithObjects:@"upnono-na0.qiniu.com", @"upnono-na0.qiniu.com", nil];
        builder.useHttps = NO;
        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
    }];

    int size = 600;
    NSString *keyUp = [NSString stringWithFormat:@"form_convert_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:size * 1024 identifier:keyUp];
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:keyUp config:config option:nil];
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
//    [upManager putData:data key:nil token:token_na0 complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
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
    NSString *key = @"form_0_size";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:0 identifier:key];
    [self allFileTypeUploadAndAssertResult:kQNZeroDataSize tempFile:tempFile key:nil config:nil option:nil];
}

@end
