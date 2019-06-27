//
//  QNReporterTest.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/27.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"
#import <AGAsyncTestHelper.h>

@interface QNReporterTest : XCTestCase
@end

@implementation QNReporterTest

- (void)setUp {
    [super setUp];
    
    NSLog(@"home directory: %@", NSHomeDirectory());
}

- (void)tearDown {
    [super tearDown];
}

- (void)testNormalRecord {
    
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    
    [UploadInfoReporter clean];
    NSURL *tempFile = [QNTempFile createTempfileWithSize:4 * 1024];
    QNUploadManager *manager = [[QNUploadManager alloc] init];
    QNUploadOption *option = [[QNUploadOption alloc] initWithProgressHandler:nil];
    [manager putFile:tempFile.path key:nil token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    } option:option];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    
    sleep(1);
    
    NSString *recordFilePath = [[QNReportConfig sharedInstance].recordDirectory stringByAppendingString:@"/recorder"];
    BOOL isRecordFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:recordFilePath];
    
    // 没有触发上传  文件应该存在
    XCTAssert(isRecordFileExisted, @"Pass");
    NSString *recordInfo = [NSString stringWithContentsOfFile:recordFilePath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"文件内容：%@", recordInfo);
}

- (void)testNormalUpload {
    
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    NSTimeInterval lastUploadTime = UploadInfoReporter.lastReportTime;
    
    [UploadInfoReporter clean];
    NSURL *tempFile = [QNTempFile createTempfileWithSize:8 * 1024 * 1024];
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.reportConfig.uploadThreshold = 100;  // 大于100字节触发上传
    }];
    QNUploadManager *manager = [[QNUploadManager alloc] initWithConfiguration:config];
    QNUploadOption *option = [[QNUploadOption alloc] initWithProgressHandler:nil];
    [manager putFile:tempFile.path key:nil token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    } option:option];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    
    AGWW_WAIT_WHILE(UploadInfoReporter.lastReportTime == lastUploadTime, 100.0);

    // 触发上传后会修改lastReportTime
    XCTAssert(lastUploadTime != UploadInfoReporter.lastReportTime, @"Pass");
}

- (void)testRecordUnable {
    
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    
    [UploadInfoReporter clean];
    NSURL *tempFile = [QNTempFile createTempfileWithSize:8 * 1024 * 1024];
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.reportConfig.recordEnable = NO;
    }];
    QNUploadManager *manager = [[QNUploadManager alloc] initWithConfiguration:config];
    QNUploadOption *option = [[QNUploadOption alloc] initWithProgressHandler:nil];
    [manager putFile:tempFile.path key:nil token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    } option:option];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    
    sleep(1);
    
    NSString *recordFilePath = [[QNReportConfig sharedInstance].recordDirectory stringByAppendingString:@"/recorder"];
    BOOL isRecordFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:recordFilePath];
    
    XCTAssert(UploadInfoReporter.lastReportTime == 0, @"Pass");
    XCTAssert(!isRecordFileExisted, @"Pass");
}

- (void)testRecordDirectory {
    
    __block QNResponseInfo *testInfo = nil;
    __block NSDictionary *testResp = nil;
    NSString *foldDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Qiniu"];
    
    NSURL *tempFile = [QNTempFile createTempfileWithSize:1 * 1024];
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.reportConfig.recordDirectory = foldDirectory;
    }];
    QNUploadManager *manager = [[QNUploadManager alloc] initWithConfiguration:config];
    QNUploadOption *option = [[QNUploadOption alloc] initWithProgressHandler:nil];
    
    [UploadInfoReporter clean];
    [manager putFile:tempFile.path key:nil token:g_token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        testInfo = info;
        testResp = resp;
    } option:option];
    
    AGWW_WAIT_WHILE(testInfo == nil, 100.0);
    NSLog(@"%@", testInfo);
    NSLog(@"%@", testResp);
    
    sleep(1);
    
    NSString *fileDirectory = [foldDirectory stringByAppendingString:@"/recorder"];
    BOOL isRecordFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:fileDirectory];
    XCTAssert(isRecordFileExisted, @"Pass");
    NSString *recordInfo = [NSString stringWithContentsOfFile:fileDirectory encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"文件内容：%@", recordInfo);
}

@end
