//
//  QNRetryTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/6/3.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNRetryTest : XCTestCase

@property(nonatomic, strong)QNUploadManager *upManager;

@end
@implementation QNRetryTest
- (void)setUp {
    [super setUp];
    _upManager = [[QNUploadManager alloc] init];
}


- (void)testUpload{
    int maxCount = 10;
    __block int completeCount = 0;
    __block int successCount = 0;
    for (int i=0; i<maxCount; i++) {
        [self template:(i+1)*100 complete:^(BOOL isSuccess){
            @synchronized (self) {
                if (isSuccess) {
                    successCount += 1;
                }
                completeCount += 1;
            }
        }];
        sleep(2);
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 60 * 30);
    XCTAssert(successCount == maxCount, @"success count:%d maxCount:%d", successCount, maxCount);
}

- (void)testAllHostsFrozen{
    
    __block BOOL isComplete = false;
    [self validHostTemplate:1024 complete:^(BOOL isSuccess){
        isComplete = true;
    }];
    AGWW_WAIT_WHILE(!isComplete, 60 * 30);
    
    int maxCount = 10;
    __block int completeCount = 0;
    __block int successCount = 0;
    for (int i=0; i<maxCount; i++) {
        [self validHostTemplate:(i + 1) * 100 complete:^(BOOL isSuccess){
            @synchronized (self) {
                if (isSuccess) {
                    successCount += 1;
                }
                completeCount += 1;
            }
        }];
        sleep(2);
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 60 * 30);
    XCTAssert(successCount == 0, @"success count:%d maxCount:%d", successCount, maxCount);
}

- (void)template:(int)size complete:(void(^)(BOOL isSuccess))complete{
    
    NSString *keyUp = [NSString stringWithFormat:@"retry_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:size * 1024 identifier:keyUp];
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];

    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        NSArray *upList = @[@"uptemp01.qbox.me", @"uptemp02.qbox.me",
                            @"uptemp03.qbox.me", @"uptemp04.qbox.me",
                            @"uptemp05.qbox.me", @"uptemp06.qbox.me",
                            @"uptemp07.qbox.me", @"uptemp08.qbox.me",
                            @"uptemp09.qbox.me", @"uptemp10.qbox.me",
                            @"uptemp11.qbox.me", @"uptemp12.qbox.me",
                            @"uptemp13.qbox.me", @"uptemp14.qbox.me",
                            @"upload-na0.qiniup.com", @"up-na0.qbox.me"];
        builder.useHttps = YES;
        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        if (i.isOK && i.reqId && [keyUp isEqualToString:k]/* && [tempFile.fileHash isEqualToString:resp[@"hash"]]*/) {
            complete(true);
        } else {
            complete(false);
        }
        
        [tempFile remove];
    } option:opt];
}

- (void)validHostTemplate:(int)size complete:(void(^)(BOOL isSuccess))complete{
    
    NSString *keyUp = [NSString stringWithFormat:@"retry_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempFileWithSize:size * 1024 identifier:keyUp];
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];

    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        NSArray *upList = @[@"uptemp01.qbox.me", @"uptemp02.qbox.me",
                            @"uptemp03.qbox.me", @"uptemp04.qbox.me",
                            @"uptemp05.qbox.me", @"uptemp06.qbox.me",
                            @"uptemp07.qbox.me", @"uptemp08.qbox.me",
                            @"uptemp09.qbox.me", @"uptemp10.qbox.me",
                            @"uptemp11.qbox.me", @"uptemp12.qbox.me",
                            @"uptemp13.qbox.me", @"uptemp14.qbox.me"];
        builder.useHttps = YES;
        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:upList];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];

    [upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        if (i.isOK && i.reqId && [keyUp isEqualToString:k]/* && [tempFile.fileHash isEqualToString:resp[@"hash"]]*/) {
            complete(true);
        } else {
            complete(false);
        }
        
        [tempFile remove];
    } option:opt];
}

@end
