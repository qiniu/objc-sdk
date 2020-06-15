//
//  QNUploadFileNameTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/6/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QiniuSDK.h"
#import "QNTestConfig.h"
#import "QNTempFile.h"

@interface QNUploadFileNameTest : XCTestCase

@property(nonatomic, strong)QNUploadManager *upManager;

@end
@implementation QNUploadFileNameTest

- (void)setUp {
    _upManager = [[QNUploadManager alloc] init];
}

- (void)tearDown {
    
}

- (void)testForm {
    NSString *name = @"\\\"-file-\"";
    [self template:name size:1];
}

- (void)testResume {
    NSString *name = @"[\"-file_\"]";
    [self template:name size:5 * 1024];
}

- (void)template:(NSString *)name size:(int)size{
    
    NSString *paramKey = @"x:foo";
    NSString *paramResponseKey = @"foo";
    NSString *paramValue = @"\"this is a test\"";
    
    NSString *keyUp = [NSString stringWithFormat:@"fileName_%@", name];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:1024 * size name:name identifier:keyUp];
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        
    } params:@{paramKey : paramValue} checkCrc:true cancellationSignal:nil];

    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useHttps = YES;
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    __block QNResponseInfo *responseInfo = nil;
    __block NSDictionary *response = nil;
    __block NSString *key = nil;
    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_z0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        response = resp;
        key = k;
        responseInfo = i;
        
    } option:opt];
    
    WAIT_WHILE(responseInfo == nil, 60);
    
    XCTAssert(responseInfo.isOK && responseInfo.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
    XCTAssert([tempFile.fileHash isEqualToString:response[@"hash"]], @"Pass");
    XCTAssert([paramValue isEqualToString:response[paramResponseKey]], @"Pass");
    XCTAssert([tempFile.fileUrl.lastPathComponent isEqualToString:response[@"fname"]], @"Pass");
    [tempFile remove];
}

@end
