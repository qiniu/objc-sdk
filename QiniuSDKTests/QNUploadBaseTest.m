//
//  QNUploadBaseTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadBaseTest.h"

@interface QNUploadBaseTest()

@end
@implementation QNUploadBaseTest

- (void)setUp {
    [super setUp];
    self.defaultOption = [[QNUploadOption alloc] initWithMime:nil
                                              progressHandler:^(NSString *key, float percent) {
        NSLog(@"== key:%@ percent:%f", key, percent);
    }
                                                       params:nil
                                                     checkCrc:YES
                                           cancellationSignal:nil];
}

- (BOOL)versionUploadKey:(NSString *)upKey responseKey:(NSString *)responseKey {
    if (upKey == nil) {
        return responseKey == nil;
    } else {
        return [upKey isEqualToString:responseKey];
    }
}

- (void)uploadFileAndAssertSuccessResult:(QNTempFile *)tempFile
                                     key:(NSString *)key
                                  config:(QNConfiguration *)config
                                  option:(QNUploadOption *)option{
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadFile:tempFile key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssertTrue(responseInfo.isOK, @"Pass");
    XCTAssertTrue(responseInfo.reqId, @"Pass");
    XCTAssertTrue([self versionUploadKey:keyUp responseKey:key], @"Pass");
}

- (void)uploadFileAndAssertResult:(int)statusCode
                         tempFile:(QNTempFile *)tempFile
                              key:(NSString *)key
                           config:(QNConfiguration *)config
                           option:(QNUploadOption *)option{
    
    [self uploadFileAndAssertResult:statusCode tempFile:tempFile token:token_na0 key:key config:config option:option];
}

- (void)uploadFileAndAssertResult:(int)statusCode
                         tempFile:(QNTempFile *)tempFile
                            token:(NSString * _Nullable)token
                              key:(NSString *)key
                           config:(QNConfiguration *)config
                           option:(QNUploadOption *)option{
   
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadFile:tempFile token:token key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssertTrue(responseInfo.statusCode == statusCode, @"Pass");
    XCTAssertTrue([self versionUploadKey:keyUp responseKey:key], @"Pass");
}

- (void)uploadFile:(QNTempFile *)tempFile
               key:(NSString *)key
            config:(QNConfiguration *)config
            option:(QNUploadOption *)option
          complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete{
    
    [self uploadFile:tempFile token:token_na0 key:key config:config option:option complete:complete];
}

- (void)uploadFile:(QNTempFile *)tempFile
             token:(NSString *)token
               key:(NSString *)key
            config:(QNConfiguration *)config
            option:(QNUploadOption *)option
          complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete {
    if (!option) {
        option = self.defaultOption;
    }
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    [upManager putFile:tempFile.fileUrl.path key:key token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        
        if (complete) {
            complete(info, key);
        }
        NSLog(@"key:%@ responseInfo:%@", key, info);
        [tempFile remove];
    } option:option];
}


- (void)uploadDataAndAssertSuccessResult:(NSData *)data
                                     key:(NSString *)key
                                  config:(QNConfiguration *)config
                                  option:(QNUploadOption *)option{
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadData:data key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssertTrue(responseInfo.isOK, @"Pass");
    XCTAssertTrue(responseInfo.reqId, @"Pass");
    XCTAssertTrue([self versionUploadKey:keyUp responseKey:key], @"Pass");
}

- (void)uploadDataAndAssertResult:(int)statusCode
                             data:(NSData *)data
                              key:(NSString *)key
                           config:(QNConfiguration *)config
                           option:(QNUploadOption *)option {
    [self uploadDataAndAssertResult:statusCode data:data token:token_na0 key:key config:config option:option];
}

- (void)uploadDataAndAssertResult:(int)statusCode
                             data:(NSData *)data
                            token:(NSString *)token
                              key:(NSString *)key
                           config:(QNConfiguration *)config
                           option:(QNUploadOption *)option {
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadData:data token:token key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssertTrue(responseInfo.statusCode == statusCode, @"Pass");
    XCTAssertTrue([self versionUploadKey:keyUp responseKey:key], @"Pass");
}

- (void)uploadData:(NSData *)data
               key:(NSString *)key
            config:(QNConfiguration *)config
            option:(QNUploadOption *)option
          complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete{
    
    [self uploadData:data token:token_na0 key:key config:config option:option complete:complete];
}

- (void)uploadData:(NSData *)data
             token:(NSString *)token
               key:(NSString *)key
            config:(QNConfiguration *)config
            option:(QNUploadOption *)option
          complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete{
    if (!option) {
        option = self.defaultOption;
    }
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    [upManager putData:data key:key token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *response) {

        if (complete) {
            complete(info, key);
        }
        NSLog(@"key:%@ responseInfo:%@", key, info);
    } option:option];
}

@end
