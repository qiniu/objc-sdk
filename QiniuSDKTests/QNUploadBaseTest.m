//
//  QNUploadBaseTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNLogUtil.h"
#import "QNUploadBaseTest.h"

@interface QNUploadBaseTest()

@end
@implementation QNUploadBaseTest

- (void)setUp {
    [super setUp];
//    [QNLogUtil setLogLevel:QNLogLevelInfo];
    
    self.defaultOption = [[QNUploadOption alloc] initWithMime:nil
                                          byteProgressHandler:^(NSString *key, long long uploadBytes, long long totalBytes) {
        NSLog(@"== key:%@ uploadBytes:%lld totalBytes:%lld", key, uploadBytes, totalBytes);
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

- (void)allFileTypeUploadAndAssertSuccessResult:(QNTempFile *)tempFile
                                            key:(NSString *)key
                                         config:(QNConfiguration *)config
                                         option:(QNUploadOption *)option {
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    tempFile.fileType = QNTempFileTypeData;
    [self uploadAndAssertSuccessResult:tempFile key:key config:config option:option];

    tempFile.fileType = QNTempFileTypeFile;
    [self uploadAndAssertSuccessResult:tempFile key:key config:config option:option];

    tempFile.fileType = QNTempFileTypeStream;
    [self uploadAndAssertSuccessResult:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeStreamNoSize;
    [self uploadAndAssertSuccessResult:tempFile key:key config:config option:option];
}

- (void)uploadAndAssertSuccessResult:(QNTempFile *)tempFile
                                 key:(NSString *)key
                              config:(QNConfiguration *)config
                              option:(QNUploadOption *)option{
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    
    [self upload:tempFile key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssertTrue(responseInfo.isOK, @"response info:%@", responseInfo);
    XCTAssertTrue(responseInfo.reqId, @"response info:%@", responseInfo);
}


- (void)allFileTypeUploadAndAssertResult:(int)statusCode
                                tempFile:(QNTempFile *)tempFile
                                     key:(NSString *)key
                                  config:(QNConfiguration *)config
                                  option:(QNUploadOption *)option {
    
    [self allFileTypeUploadAndAssertResult:statusCode tempFile:tempFile token:token_na0 key:key config:config option:option];
}

- (void)uploadAndAssertResult:(int)statusCode
                     tempFile:(QNTempFile *)tempFile
                          key:(NSString *)key
                       config:(QNConfiguration *)config
                       option:(QNUploadOption *)option{
    
    [self uploadAndAssertResult:statusCode tempFile:tempFile token:token_na0 key:key config:config option:option];
}

- (void)allFileTypeUploadAndAssertResult:(int)statusCode
                                tempFile:(QNTempFile *)tempFile
                                   token:(NSString * _Nullable)token
                                     key:(NSString *)key
                                  config:(QNConfiguration *)config
                                  option:(QNUploadOption *)option {
    
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    tempFile.fileType = QNTempFileTypeData;
    [self uploadAndAssertResult:statusCode tempFile:tempFile token:token key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeFile;
    [self uploadAndAssertResult:statusCode tempFile:tempFile token:token key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeStream;
    [self uploadAndAssertResult:statusCode tempFile:tempFile token:token key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeStreamNoSize;
    [self uploadAndAssertResult:statusCode tempFile:tempFile token:token key:key config:config option:option];
}

- (void)uploadAndAssertResult:(int)statusCode
                     tempFile:(QNTempFile *)tempFile
                        token:(NSString * _Nullable)token
                          key:(NSString *)key
                       config:(QNConfiguration *)config
                       option:(QNUploadOption *)option {
   
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self upload:tempFile token:token key:key config:config option:option complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssertTrue(responseInfo.statusCode == statusCode, @"response info:%@", responseInfo);
}

- (void)upload:(QNTempFile *)tempFile
           key:(NSString *)key
        config:(QNConfiguration *)config
        option:(QNUploadOption *)option
      complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete{
    
    [self upload:tempFile token:token_na0 key:key config:config option:option complete:complete];
}

- (void)upload:(QNTempFile *)tempFile
         token:(NSString *)token
           key:(NSString *)key
        config:(QNConfiguration *)config
        option:(QNUploadOption *)option
      complete:(void(^)(QNResponseInfo *responseInfo, NSString *key))complete {
    if (!option) {
        option = self.defaultOption;
    }
    BOOL shouldCheckHash = YES;
    if (!key || key.length == 0 || tempFile.size < 1 || (config.resumeUploadVersion == QNResumeUploadVersionV2 && config.chunkSize != kQNBlockSize)) {
        shouldCheckHash = NO;
    }
    
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    if (tempFile.fileType == QNTempFileTypeData) {
        if (key != nil && key.length != 0) {
            key = [NSString stringWithFormat:@"%@_data", key];
        }
        
        kQNWeakSelf;
        [upManager putData:tempFile.data key:key token:token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
            kQNStrongSelf;
            XCTAssertTrue([self versionUploadKey:key responseKey:k], @"keyUp:%@ key:%@", key, k);
            if (shouldCheckHash && info.isOK) {
                NSString *serverHash = resp[@"hash"];
                XCTAssertTrue([tempFile.fileHash isEqualToString:serverHash], @"hash:%@ serverHash:%@", tempFile.fileHash, serverHash);
            }
            
            if (complete) {
                complete(info, key);
            }
            NSLog(@"key:%@ responseInfo:%@", key, info);
            if (tempFile.canRemove) {
                [tempFile remove];
            }
        } option:option];
    } else if (tempFile.fileType == QNTempFileTypeStream || tempFile.fileType == QNTempFileTypeStreamNoSize) {
        if (key != nil && key.length != 0) {
            if (tempFile.fileType == QNTempFileTypeStream) {
                key = [NSString stringWithFormat:@"%@_stream_has_size", key];
            } else {
                key = [NSString stringWithFormat:@"%@_stream_none_size", key];
            }
        }
        kQNWeakSelf;
        [upManager putInputStream:tempFile.inputStream sourceId:key size:tempFile.size fileName:key key:key token:token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
            kQNStrongSelf;
            XCTAssertTrue([self versionUploadKey:key responseKey:k], @"keyUp:%@ key:%@", key, k);
            if (shouldCheckHash && info.isOK) {
                NSString *serverHash = resp[@"hash"];
                XCTAssertTrue([tempFile.fileHash isEqualToString:serverHash], @"hash:%@ serverHash:%@", tempFile.fileHash, serverHash);
            }
            
            if (complete) {
                complete(info, key);
            }
            NSLog(@"key:%@ responseInfo:%@", key, info);
            if (tempFile.canRemove) {
                [tempFile remove];
            }
        } option:option];
    } else {
        if (key != nil && key.length != 0) {
            key = [NSString stringWithFormat:@"%@_file", key];
        }
        kQNWeakSelf;
        [upManager putFile:tempFile.fileUrl.path key:key token:token complete:^(QNResponseInfo *info, NSString *k, NSDictionary *resp) {
            kQNStrongSelf;
            XCTAssertTrue([self versionUploadKey:key responseKey:k], @"keyUp:%@ key:%@", key, k);
            if (shouldCheckHash && info.isOK) {
                NSString *serverHash = resp[@"hash"];
                XCTAssertTrue([tempFile.fileHash isEqualToString:serverHash], @"hash:%@ serverHash:%@", tempFile.fileHash, serverHash);
            }
            
            if (complete) {
                complete(info, key);
            }
            NSLog(@"key:%@ responseInfo:%@", key, info);
            if (tempFile.canRemove) {
                [tempFile remove];
            }
        } option:option];
    }
    
}

@end
