//
//  QNConcurrentResumeUploadTest.m
//  QiniuSDK_MacTests
//
//  Created by WorkSpace_Sun on 2019/10/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNConcurrentResumeUploadTest : XCTestCase
@property QNUploadManager *upManager;
@end

@implementation QNConcurrentResumeUploadTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    kQNGlobalConfiguration.isDnsOpen = YES;
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = YES;
    }];
    _upManager = [[QNUploadManager alloc] initWithConfiguration:config];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    _upManager = nil;
}

- (void)testCancel {
    int size = 6 * 1024;
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_cancel_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    __block BOOL flag = NO;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        flag = YES;
    }
        params:@{ @"x:lan" : @"objc" }
        checkCrc:YES
        cancellationSignal:^BOOL() {
            return flag;
        }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
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

- (void)template:(int)size {
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_template_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    __block NSDictionary *response = nil;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
        response = resp;
    }
                 option:opt];
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert(info.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
//    XCTAssert([tempFile.fileHash isEqualToString:response[@"hash"]], @"Pass");
    [tempFile remove];
}

- (void)templateHttps:(int)size {
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_templateHttps_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    __block NSDictionary *response = nil;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];

    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        NSArray *upList = [[NSArray alloc] initWithObjects:@"uptemp.qbox.me", nil];
        builder.useHttps = YES;
        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
        builder.useConcurrentResumeUpload = YES;
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
        response = resp;
    }
                option:opt];
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert(info.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
//    XCTAssert([tempFile.fileHash isEqualToString:response[@"hash"]], @"Pass");
    [tempFile remove];
}

- (void)testNoKey {
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_NoKey_%dk", 600];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:600 * 1024 identifier:keyUp];
    __block QNResponseInfo *info = nil;
    __block NSDictionary *testResp = nil;
    __block NSString *key = nil;
    [_upManager putFile:tempFile.fileUrl.path key:nil token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
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
//    XCTAssert([tempFile.fileHash isEqualToString:testResp[@"key"]], @"Pass");
//    XCTAssert([tempFile.fileHash isEqualToString:testResp[@"hash"]], @"Pass");
    [tempFile remove];
}

- (void)test0k {
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:0];
    NSString *keyUp = [NSString stringWithFormat:@"%dk", 0];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
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

- (void)test1M {
    [self template:1024];
}

- (void)test3M {
    [self template:3 * 1024];
}

- (void)test4M {
    [self template:4 * 1024];
}

- (void)test5M {
    [self template:5 * 1024];
}

- (void)test8M {
    [self template:8 * 1024 + 1];
}

- (void)test20M {
    [self template:20*1024 + 1];
}

- (void)testReupload{
    
    NSString *keyUp = @"concurrent_reupload_20M";
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
        builder.useConcurrentResumeUpload = YES;
        builder.useHttps = YES;
        builder.chunkSize = 1 * 1024 * 1024;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniu"] error:nil];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    } option:opt];
    
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"Reupload ================");
    key = nil;
    isReupload = YES;
    
    QNUploadManager *upManager_re = [[QNUploadManager alloc] initWithConfiguration:config];
    [upManager_re putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    } option:opt];
    
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");

    [tempFile remove];
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
//        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
//    }];
//
//    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
//
//    int size = 600;
//    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024];
//    NSString *keyUp = [NSString stringWithFormat:@"%dkproxy", size];
//    __block QNResponseInfo *info = nil;
//    __block NSString *key = nil;
//    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
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
        NSArray *upList = [[NSArray alloc] initWithObjects:@"up-na0.qiniu.com", @"up-na0.qiniu.com", nil];
        builder.useHttps = NO;
        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
    }];

    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    int size = 600;
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_convert_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block QNResponseInfo *info = nil;
    __block NSString *key = nil;
    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    }
                option:nil];

    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
    XCTAssert([info.host isEqual:@"up-na0.qiniu.com"], @"Pass");
    [tempFile remove];
}

@end
