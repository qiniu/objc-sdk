//
//  QNResumeUploadTest.m
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

@interface QNResumeUploadTest : QNUploadFlowTest
@property BOOL inTravis;
@end

@implementation QNResumeUploadTest

- (void)setUp {
    [super setUp];
#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
    NSString *travis = [[NSProcessInfo processInfo] environment][@"QINIU_TEST_ENV"];
    if ([travis isEqualToString:@"travis"]) {
        _inTravis = YES;
    }
#endif
}

- (void)tearDown {
}

- (void)testSwitchRegionV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_switch_region_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeSwitchRegionTestWithFile:tempFile key:key config:config option:nil];
    }
}

- (void)testCancelV1 {
    float cancelPercent = 0.1;
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@30000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_cancel_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeCancelTest:cancelPercent * size.longLongValue * 1024 tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testHttpV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_http_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testHttpsV1 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_https_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testReuploadV1 {
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
        builder.chunkSize = 1 * 1024 * 1024;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniu"] error:nil];
    }];
    
    NSArray *sizeArray = @[@30000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_reupload_v1_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeResumeUploadTest:0.5 * 1024 * size.longLongValue  tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testNoKeyV1 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    
    NSString *keyUp = [NSString stringWithFormat:@"resume_NoKey_v1_%dk", 600];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:600 * 1024 identifier:keyUp];
    tempFile.canRemove = NO;
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:nil config:configHttp option:nil];
    
    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:nil config:configHttps option:nil];
}

- (void)test0kV1 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    
    NSString *key = @"resume_0k_v1_0k";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:0 identifier:key];
    tempFile.canRemove = NO;
    [self allFileTypeUploadAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttp option:nil];

    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    [self allFileTypeUploadAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttps option:nil];

}

- (void)testCustomParamV1 {
    
    NSDictionary *userParam = @{@"x:foo" : @"foo_value",
                                @"x:bar" : @"bar_value"};
    NSDictionary *metaParam = @{@"0000" : @"meta_value_0",
                                @"x-qn-meta-aaa" : @"meta_value_1",
                                @"x-qn-meta-key-2" : @"meta_value_2"};
    QNUploadOption *option = [[QNUploadOption alloc] initWithMime:nil
                                                  progressHandler:nil
                                                           params:userParam
                                                   metaDataParams:metaParam
                                                         checkCrc:YES
                                               cancellationSignal:nil];
    
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    
    NSString *key = @"resume_custom_param_v1";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1024 * 1024 * 5 identifier:key];
    
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:configHttp option:option];
}


- (void)testSwitchRegionV2 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_switch_region_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeSwitchRegionTestWithFile:tempFile key:key config:config option:nil];
    }
}

- (void)testCancelV2 {
    float cancelPercent = 0.1;
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@30000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_cancel_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeCancelTest:cancelPercent * size.longLongValue * 1024 tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testHttpV2 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_http_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testHttpsV2 {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    NSArray *sizeArray = @[@500, @1000, @3000, @4000, @5000, @8000, @10000, @20000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_https_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:config option:nil];
    }
}


- (void)testReuploadV2 {
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
        builder.chunkSize = 1 * 1024 * 1024;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniu"] error:nil];
    }];
    
    NSArray *sizeArray = @[@30000];
    for (NSNumber *size in sizeArray) {
        NSString *key = [NSString stringWithFormat:@"resume_reupload_v2_%@k", size];
        QNTempFile *tempFile = [QNTempFile createTempFileWithSize:[size intValue] * 1024 identifier:key];
        [self allFileTypeResumeUploadTest:0.5 * 1024 * size.longLongValue tempFile:tempFile key:key config:config option:nil];
    }
}

- (void)testNoKeyV2 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.concurrentTaskCount = 3;
        builder.useHttps = NO;
    }];
    
    NSString *keyUp = [NSString stringWithFormat:@"resume_NoKey_v2_%dk", 600];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:600 * 1024 identifier:keyUp];
    tempFile.canRemove = NO;
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:nil config:configHttp option:nil];
    
    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = YES;
    }];
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:nil config:configHttps option:nil];
}

- (void)test0kV2 {
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    
    NSString *key = @"resume_v2_0k";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:0 identifier:key];
    tempFile.canRemove = NO;
    [self uploadAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttp option:nil];

    tempFile.canRemove = YES;
    QNConfiguration *configHttps = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
           builder.useConcurrentResumeUpload = NO;
           builder.concurrentTaskCount = 3;
           builder.useHttps = YES;
       }];
    [self allFileTypeUploadAndAssertResult:kQNZeroDataSize tempFile:tempFile key:key config:configHttps option:nil];

}

- (void)testCustomParamV2 {
    
    NSDictionary *userParam = @{@"x:foo" : @"foo_value",
                                @"x:bar" : @"bar_value"};
    NSDictionary *metaParam = @{@"0000" : @"meta_value_0",
                                @"x-qn-meta-aaaa" : @"meta_value_1",
                                @"x-qn-meta-key-2" : @"meta_value_2"};
    QNUploadOption *option = [[QNUploadOption alloc] initWithMime:nil
                                                  progressHandler:nil
                                                           params:userParam
                                                   metaDataParams:metaParam
                                                         checkCrc:YES
                                               cancellationSignal:nil];
    
    QNConfiguration *configHttp = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        builder.useConcurrentResumeUpload = NO;
        builder.useHttps = NO;
    }];
    
    NSString *key = @"resume_custom_param_v2";
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:1024 * 1024 * 5 identifier:key];
    
    [self allFileTypeUploadAndAssertSuccessResult:tempFile key:key config:configHttp option:option];
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
