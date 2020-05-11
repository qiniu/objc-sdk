//
//  QNResumeUploadTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNResumeUploadTest : XCTestCase
@property QNUploadManager *upManager;
@property BOOL inTravis;
@end

@implementation QNResumeUploadTest

- (void)setUp {
    [super setUp];
    _upManager = [[QNUploadManager alloc] init];
#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
    NSString *travis = [[NSProcessInfo processInfo] environment][@"QINIU_TEST_ENV"];
    if ([travis isEqualToString:@"travis"]) {
        _inTravis = YES;
    }
#endif
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCancel {
    int size = 6 * 1024;
    NSString *keyUp = [NSString stringWithFormat:@"resume_cancel_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    __block BOOL flag = NO;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        flag = YES;
    }
        params:@{ @"x:lan" : @"objc" }
        checkCrc:NO
        cancellationSignal:^BOOL() {
            return flag;
        }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    }
                 option:opt];

    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isCancelled, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");

    [tempFile remove];
}

- (void) template:(int)size {
    NSString *keyUp = [NSString stringWithFormat:@"resume_template_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block NSDictionary *testResp = nil;
    __block QNResponseInfo *info = nil;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
        testResp = resp;
    }
                 option:opt];
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert(info.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
    XCTAssert([tempFile.fileHash isEqualToString:testResp[@"hash"]], @"Pass");
    [tempFile remove];
}

- (void)templateHttps:(int)size {
    NSString *keyUp = [NSString stringWithFormat:@"resume_templateHttps_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block NSDictionary *testResp = nil;
    __block QNResponseInfo *info = nil;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];

    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        NSArray *upList = [[NSArray alloc] initWithObjects:@"uptemp.qbox.me", nil];
        builder.useHttps = YES;
        builder.zone = [[QNFixedZone alloc] initWithupDomainList:upList];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    [upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
        testResp = resp;
    }
                option:opt];
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert(info.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
    XCTAssert([tempFile.fileHash isEqualToString:testResp[@"hash"]], @"Pass");
    [tempFile remove];
}

- (void)testNoKey {
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:600 * 1024 identifier:@"resume_nokey"];
    __block QNResponseInfo *info = nil;
    __block NSDictionary *testResp = nil;
    __block NSString *key = nil;
    [_upManager putFile:tempFile.fileUrl.path key:nil token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
        testResp = resp;
    }
                 option:nil];
    AGWW_WAIT_WHILE(info == nil, 60 * 30);
    NSLog(@"resp %@", testResp);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert(info.reqId, @"Pass");
    XCTAssert(key == nil, @"Pass");
    XCTAssert([@"FlUVjj3un6gu8Kaa1f2SdA1E5oD_" isEqualToString:testResp[@"key"]], @"Pass");
    XCTAssert([tempFile.fileHash isEqualToString:testResp[@"hash"]], @"Pass");
    [tempFile remove];
}

- (void)test0k {
    NSString *keyUp = [NSString stringWithFormat:@"resume_%dk", 0];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:0 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    }
                 option:opt];
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.statusCode == kQNZeroDataSize, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");

    [tempFile remove];
}

- (void)test500k {
    [self template:500];
}

- (void)test600k {
    [self template:600];
}

- (void)test3M {
    [self template:3 * 1024];
}

- (void)test5M {
    [self template:5 * 1024];
}

- (void)test10M {
    [self template:10 * 1024];
}

- (void)testReupload{
    
    NSString *keyUp = @"resume_reupload_20M";
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize: 20 * 1024 * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    __block BOOL flag = NO;
    __block BOOL isReupload = NO;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil
                                               progressHandler:^(NSString *key, float percent) {
        if (percent > 0.8) {
            flag = YES;
        }
        NSLog(@"Reupload progress %f", percent);
    }
                                                        params:@{ @"x:lan" : @"objc" }
                                                      checkCrc:NO
                                            cancellationSignal:^BOOL() {
        if (isReupload) {
            return NO;
        } else {
            return flag;
        }
    }];
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
        builder.chunkSize = 1 * 1024 * 1024;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniu"] error:nil];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    [upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    } option:opt];
    
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"Reupload ================");
    key = nil;
    isReupload = YES;
    
    QNUploadManager *upManager_re = [[QNUploadManager alloc] initWithConfiguration:config];
    [upManager_re putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    } option:opt];
    
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");

    [tempFile remove];
}

//- (void)test500ks {
//    [self templateHttps:500];
//}
//
//- (void)test600ks {
//    [self templateHttps:600];
//}

#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED

- (void)test1M {
    if (_inTravis) {
        return;
    }
    [self template:1024];
}

- (void)test4M {
    if (_inTravis) {
        return;
    }
    [self template:4 * 1024];
}

- (void)test8M {
    if (_inTravis) {
        return;
    }
    [self template:8 * 1024 + 1];
}

//- (void)testProxy {
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
//    int size = 600;
//    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024];
//    NSString *keyUp = [NSString stringWithFormat:@"%dkproxy", size];
//    __block QNResponseInfo *info = nil;
//    __block NSString *key = nil;
//    [upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
//        key = k;
//        info = i;
//    }
//                option:nil];
//
//    AGWW_WAIT_WHILE(key == nil, 60 * 30);
//    NSLog(@"info %@", info);
//    XCTAssert(info.isOK, @"Pass");
//    XCTAssert([keyUp isEqualToString:key], @"Pass");
//
//    [tempFile remove];
//}

- (void)testUrlConvert {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.converter = ^NSString *(NSString *url) {
            return [url stringByReplacingOccurrencesOfString:@"upnono" withString:@"up"];
        };
        NSArray *upList = [[NSArray alloc] initWithObjects:@"upnono.qiniu.com", @"upnono.qiniu.com", nil];
        builder.useHttps = NO;
        builder.zone = [[QNFixedZone alloc] initWithupDomainList:upList];
    }];

    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    int size = 600;
    NSString *keyUp = [NSString stringWithFormat:@"resume_convert_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:600 * 1024 identifier:keyUp];
    __block QNResponseInfo *info = nil;
    __block NSString *key = nil;
    [upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    }
                option:nil];

    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
    XCTAssert([info.host isEqual:@"up.qiniu.com"], @"Pass");
    [tempFile remove];
}

//- (void)testHosts {
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
//    int size = 600;
//    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024];
//    NSString *keyUp = [NSString stringWithFormat:@"%dkconvert", size];
//    __block QNResponseInfo *info = nil;
//    __block NSString *key = nil;
//    [upManager putFile:tempFile.fileUrl.path key:keyUp token:g_token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
//        key = k;
//        info = i;
//    }
//                option:nil];
//
//    AGWW_WAIT_WHILE(key == nil, 60 * 30);
//    NSLog(@"info %@", info);
//    XCTAssert(info.isOK, @"Pass");
//    XCTAssert([keyUp isEqualToString:key], @"Pass");
//    XCTAssert([info.host isEqual:@"uphosttest.qiniu.com"] || [info.host isEqual:@"uphosttestbak.qiniu.com"], @"Pass");
//    [tempFile remove];
//}

#endif
@end
