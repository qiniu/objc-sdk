//
//  QNUploadBaseTest.h
//  QiniuSDK
//
//  Created by yangsen on 2020/12/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//
#import "QNTestConfig.h"
#import "QNTempFile.h"
#import "QiniuSDK.h"
#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadBaseTest : XCTestCase

- (void)uploadFileAndAssertSuccessResult:(QNTempFile * _Nullable)tempFile
                                     key:(NSString * _Nullable)key
                                  config:(QNConfiguration * _Nullable)config
                                  option:(QNUploadOption * _Nullable)option;

- (void)uploadFileAndAssertResult:(int)statusCode
                         tempFile:(QNTempFile * _Nullable)tempFile
                              key:(NSString * _Nullable)key
                           config:(QNConfiguration * _Nullable)config
                           option:(QNUploadOption * _Nullable)option;

- (void)uploadFile:(QNTempFile * _Nullable)tempFile
               key:(NSString * _Nullable)key
            config:(QNConfiguration * _Nullable)config
            option:(QNUploadOption * _Nullable)option
          complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete;

- (void)uploadDataAndAssertSuccessResult:(NSData * _Nullable)data
                                     key:(NSString * _Nullable)key
                                  config:(QNConfiguration * _Nullable)config
                                  option:(QNUploadOption * _Nullable)option;

- (void)uploadDataAndAssertResult:(int)statusCode
                             data:(NSData *)data
                              key:(NSString *)key
                           config:(QNConfiguration *)config
                           option:(QNUploadOption *)option;

- (void)uploadData:(NSData * _Nullable)data
               key:(NSString * _Nullable)key
            config:(QNConfiguration * _Nullable)config
            option:(QNUploadOption * _Nullable)option
          complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete;

@end

NS_ASSUME_NONNULL_END
