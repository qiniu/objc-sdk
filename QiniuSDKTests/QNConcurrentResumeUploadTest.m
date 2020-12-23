//
//  QNConcurrentResumeUploadTest.m
//  QiniuSDK_MacTests
//
//  Created by WorkSpace_Sun on 2019/10/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNUploadFlowTest.h"
#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNConcurrentResumeUploadTest : QNUploadFlowTest

@end

@implementation QNConcurrentResumeUploadTest

- (void)setUp {
    kQNGlobalConfiguration.isDnsOpen = YES;
}

- (void)tearDown {
}

- (void)testSwitchRegionV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = true;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@5000, @8000, @10000, @20000];
    sizeArray = @[@5000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_resume_switch_region_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self switchRegionTestWithFile:tempFile key:key config:config option:nil];
    }
}

- (void)testCancelV1 {
    float cancelPercent = 0.5;
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 2;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_cancel_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self cancelTest:cancelPercent tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testHttpV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_http_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self uploadFileAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testHttpsV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_https_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self uploadFileAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testReuploadV1 {
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 2;
        builder.useHttps = YES;
        builder.chunkSize = 1 * 1024 * 1024;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniu"] error:nil];
    }];
    
    NSArray *sizeArray = @[@30000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_reupload_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self resumeUploadTest:0.5 tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testNoKeyV1 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_NoKey_v1_%dk", 600];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:600 * 1024 identifier:keyUp];
    tempFile.canRemove = NO;
    [self uploadFileAndAssertSuccessResult:tempFile key:nil config:configHttp option:nil];
    
    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = YES;
    }];
    [self uploadFileAndAssertSuccessResult:tempFile key:nil config:configHttps option:nil];
}

- (void)test0kV1 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    
    NSString *key = @"concurrent_v1_0k";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:0 identifier:key];
    tempFile.canRemove = NO;
    [self uploadFileAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttp option:nil];

    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = YES;
    }];
    [self uploadFileAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttps option:nil];

}


- (void)testSwitchRegionV2 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = true;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@5000, @8000, @10000, @20000];
    sizeArray = @[@5000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_resume_switch_region_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self switchRegionTestWithFile:tempFile key:key config:config option:nil];
    }
}

- (void)testCancelV2 {
    float cancelPercent = 0.5;
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 2;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_cancel_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self cancelTest:cancelPercent tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testHttpV2 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_http_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self uploadFileAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testHttpsV2 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_https_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self uploadFileAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testReuploadV2 {
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 2;
        builder.useHttps = YES;
        builder.chunkSize = 1 * 1024 * 1024;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniu"] error:nil];
    }];
    
    NSArray *sizeArray = @[@30000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"concurrent_reupload_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self resumeUploadTest:0.5 tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testNoKeyV2 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    
    NSString *keyUp = [NSString stringWithFormat:@"concurrent_NoKey_v2_%dk", 600];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:600 * 1024 identifier:keyUp];
    tempFile.canRemove = NO;
    [self uploadFileAndAssertSuccessResult:tempFile key:nil config:configHttp option:nil];
    
    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = YES;
    }];
    [self uploadFileAndAssertSuccessResult:tempFile key:nil config:configHttps option:nil];
}

- (void)test0kV2 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    
    NSString *key = @"concurrent_v2_0k";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:0 identifier:key];
    tempFile.canRemove = NO;
    [self uploadFileAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttp option:nil];

    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
           builder.useConcurrentResumeUpload = YES;
           builder.concurrentTaskCount = 3;
           builder.useHttps = YES;
       }];
    [self uploadFileAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttps option:nil];

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

@end
