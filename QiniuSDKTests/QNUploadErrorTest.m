//
//  QNUploadErrorTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/11.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNUploadErrorTestParam : NSObject

@property(nonatomic,   copy)NSString *token;
@property(nonatomic,   copy)NSString *key;
@property(nonatomic, strong)QNTempFile *tempFile;

@end
@implementation QNUploadErrorTestParam
+ (instancetype)param{
    QNUploadErrorTestParam *p = [[QNUploadErrorTestParam alloc] init];
    p.token = token_na0;
    p.key = @"upload_error_128K";
    p.tempFile = [QNTempFile createTempFileWithSize:128 * 1024 identifier:p.key];
    return p;
}
@end

@interface QNUploadErrorTest : XCTestCase

@end

@implementation QNUploadErrorTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testError_400 {
    
}

- (void)testError_401{
    QNUploadErrorTestParam *param = [QNUploadErrorTestParam param];
    param.token = @"jH983zIUFIP1OVumiBVGeAfiLYJvwrF45S-t22eu:5Ee-ICYAd_SAZKO_DLfyJQVHsQ=:eyJzY29wZSI6InpvbmUwLXNwYWNlIiwiZGVhZGxpbmUiOjE1ODkyNjAxNzR9";
    
    __block BOOL isComplete = NO;
    [self upload:param complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        XCTAssert(i.statusCode == 401, @"response info:%@", i);
        isComplete = YES;
    }];
    
    AGWW_WAIT_WHILE(isComplete == NO, 60 * 30);
}

- (void)testError_414{
    NSMutableString *key = [NSMutableString string];
    while (key.length < 800) {
        [key appendString:@"ABCDEFGHIJKLMNOPQRST"];
    }
    QNUploadErrorTestParam *param = [QNUploadErrorTestParam param];
    param.key = key;
    __block BOOL isComplete = NO;
    [self upload:param complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        XCTAssert(i.statusCode == 414, @"response info:%@", i);
        isComplete = YES;
    }];
    
    AGWW_WAIT_WHILE(isComplete == NO, 60 * 30);
}

- (void)testError_614{
    QNUploadErrorTestParam *param = [QNUploadErrorTestParam param];
    param.tempFile = [QNTempFile createTempFileWithSize:128];
    
    __block BOOL isComplete = NO;
    [self upload:param complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        XCTAssert(i.statusCode == 614, @"response info:%@", i);
        isComplete = YES;
    }];
    
    AGWW_WAIT_WHILE(isComplete == NO, 60 * 30);
}

- (void)testError_631{
    
    QNUploadErrorTestParam *param = [QNUploadErrorTestParam param];
    param.token = invalidBucketToken;
    
    __block BOOL isComplete = NO;
    [self upload:param complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        XCTAssert(i.statusCode == 631, @"response info:%@", i);
        isComplete = YES;
    }];
    
    AGWW_WAIT_WHILE(isComplete == NO, 60 * 30);
}


- (void)upload:(QNUploadErrorTestParam *)param
      complete:(void(^)(QNResponseInfo *i, NSString *k, NSDictionary *resp))complete{
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    
    [upManager putFile:param.tempFile.fileUrl.path key:param.key token:param.token complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        complete(i, k, resp);
    } option:opt];
    
    [param.tempFile remove];
}

@end
