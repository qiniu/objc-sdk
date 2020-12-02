//
//  QNUploadBaseTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadBaseTest.h"

@implementation QNUploadBaseTest

- (void)uploadFileAndAssertSuccessResult:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option{
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadFile:tempFile key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.isOK, @"Pass");
    XCTAssert(responseInfo.reqId, @"Pass");
    if (key == nil) {
        XCTAssert(keyUp == nil, @"Pass");
    } else {
        XCTAssert([keyUp isEqualToString:key], @"Pass");
    }
}

- (void)uploadFileAndAssertResult:(int)statusCode tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option{
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadFile:tempFile key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.statusCode == statusCode, @"Pass");
    if (key == nil) {
        XCTAssert(keyUp == nil, @"Pass");
    } else {
        XCTAssert([keyUp isEqualToString:key], @"Pass");
    }
}

- (void)uploadFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete{
    
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    [upManager putFile:tempFile.fileUrl.path key:key token:token_na0 complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        
        if (complete) {
            complete(info, key);
        }
        
        [tempFile remove];
    } option:option];
}


- (void)uploadDataAndAssertSuccessResult:(NSData *)data key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option{
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadData:data key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.isOK, @"Pass");
    XCTAssert(responseInfo.reqId, @"Pass");
    if (key == nil) {
        XCTAssert(keyUp == nil, @"Pass");
    } else {
        XCTAssert([keyUp isEqualToString:key], @"Pass");
    }
}

- (void)uploadDataAndAssertResult:(int)statusCode data:(NSData *)data key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadData:data key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.statusCode == statusCode, @"Pass");
    if (key == nil) {
        XCTAssert(keyUp == nil, @"Pass");
    } else {
        XCTAssert([keyUp isEqualToString:key], @"Pass");
    }
}

- (void)uploadData:(NSData *)data key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete{
    
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    [upManager putData:data key:key token:token_na0 complete:^(QNResponseInfo *info, NSString *key, NSDictionary *response) {

        if (complete) {
            complete(info, key);
        }
        
    } option:option];
}

@end
