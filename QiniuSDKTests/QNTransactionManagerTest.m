//
//  QNHttpTransactionTest.m
//  QiniuSDK
//
//  Created by 杨森 on 2020/7/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNTestConfig.h"
#import "XCTestCase+QNTest.h"
#import "QNTempFile.h"
#import "QNUpToken.h"
#import "QNRequestTransaction.h"

@interface QNTransactionManagerTest : XCTestCase

@end

@implementation QNTransactionManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)notestPartInit {
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:@[@"up.qiniup.com"] ioHosts:nil token:[QNUpToken parse:token_z0]];
    
    [transaction initPart:@"upload_v2" complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        // @"uploadId" : @"5f1e85dc565be41dbc889c8e"
        // @"expireAt" : (long)1596440668
        [self contine];
    }];
    
    [self wait];
}

- (void)notestUploadData{
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:@[@"up.qiniup.com"] ioHosts:nil token:[QNUpToken parse:token_z0]];
    
    QNTempFile *file = [QNTempFile createTempfileWithSize:2*1024*1024 + 1 name:@"upload_v2"];
    NSData *uploadData = [NSData dataWithContentsOfFile:file.fileUrl.path];
    [transaction uploadPart:@"upload_v2" uploadId:@"5f1eb112565be41dbc88b6a7" partIndex:1 partData:uploadData progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        
    } complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        
        [self contine];
    }];
    
    [self wait];
}

- (void)notestCompleteParts{
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:@[@"up.qiniup.com"] ioHosts:nil token:[QNUpToken parse:token_z0]];
    
    NSArray *partInfoArray = @[@{@"etag" : @"FsQX62B0uLo0lNnZzlwQfuPYqOmh", @"partNumber" : @1},
                               @{@"etag" : @"Fro2EBE0hVVsx8WAUhi897137Blm", @"partNumber" : @2}];
    QNTempFile *file = [QNTempFile createTempfileWithSize:50*1024 name:@"upload_v2"];

    [transaction completeParts:@"upload_v2" uploadId:@"5f1e85dc565be41dbc889c8e" partInfoArray:partInfoArray complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        
    }];
    
    [self wait];
}

@end
