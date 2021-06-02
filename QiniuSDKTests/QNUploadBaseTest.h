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

@property(nonatomic, strong)QNUploadOption *defaultOption;

- (BOOL)versionUploadKey:(NSString *)upKey
             responseKey:(NSString *)responseKey;

- (void)allFileTypeUploadAndAssertSuccessResult:(QNTempFile * _Nullable)tempFile
                                            key:(NSString * _Nullable)key
                                         config:(QNConfiguration * _Nullable)config
                                         option:(QNUploadOption * _Nullable)option;

- (void)uploadAndAssertSuccessResult:(QNTempFile * _Nullable)tempFile
                                 key:(NSString * _Nullable)key
                              config:(QNConfiguration * _Nullable)config
                              option:(QNUploadOption * _Nullable)option;

- (void)allFileTypeUploadAndAssertResult:(int)statusCode
                                tempFile:(QNTempFile * _Nullable)tempFile
                                     key:(NSString * _Nullable)key
                                  config:(QNConfiguration * _Nullable)config
                                  option:(QNUploadOption * _Nullable)option;

- (void)uploadAndAssertResult:(int)statusCode
                     tempFile:(QNTempFile * _Nullable)tempFile
                          key:(NSString * _Nullable)key
                       config:(QNConfiguration * _Nullable)config
                       option:(QNUploadOption * _Nullable)option;

- (void)allFileTypeUploadAndAssertResult:(int)statusCode
                                tempFile:(QNTempFile * _Nullable)tempFile
                                   token:(NSString * _Nullable)token
                                     key:(NSString * _Nullable)key
                                  config:(QNConfiguration * _Nullable)config
                                  option:(QNUploadOption * _Nullable)option;

- (void)uploadAndAssertResult:(int)statusCode
                     tempFile:(QNTempFile * _Nullable)tempFile
                        token:(NSString * _Nullable)token
                          key:(NSString * _Nullable)key
                       config:(QNConfiguration * _Nullable)config
                       option:(QNUploadOption * _Nullable)option;

- (void)upload:(QNTempFile * _Nullable)tempFile
           key:(NSString * _Nullable)key
        config:(QNConfiguration * _Nullable)config
        option:(QNUploadOption * _Nullable)option
      complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete;

- (void)upload:(QNTempFile * _Nullable)tempFile
         token:(NSString * _Nullable)token
           key:(NSString * _Nullable)key
        config:(QNConfiguration * _Nullable)config
        option:(QNUploadOption * _Nullable)option
      complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete;

@end

NS_ASSUME_NONNULL_END
