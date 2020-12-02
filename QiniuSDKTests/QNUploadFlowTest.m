//
//  QNUploadFlowTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadFlowTest.h"

@implementation QNUploadFlowTest

- (void)cancelTest:(float)cancelPercent tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    __block BOOL cancelFlag = NO;
    QNUploadOption *cancelOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        if (cancelPercent >= percent) {
            cancelFlag = YES;
        }
    }
        params:option.params
        checkCrc:option.checkCrc
        cancellationSignal:^BOOL() {
            return cancelFlag;
        }];
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadFile:tempFile key:key config:config option:cancelOption complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.isCancelled, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
}


- (void)cancelTest:(float)cancelPercent data:(NSData *)data key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    __block BOOL cancelFlag = NO;
    QNUploadOption *cancelOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        if (cancelPercent >= percent) {
            cancelFlag = YES;
        }
    }
        params:option.params
        checkCrc:option.checkCrc
        cancellationSignal:^BOOL() {
            return cancelFlag;
        }];
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self uploadData:data key:key config:config option:cancelOption complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.isCancelled, @"Pass");
    XCTAssert(responseInfo.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
}

//MARK: ----- 断点续传
- (void)resumeUploadTest:(float)resumePercent tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    tempFile.canRemove = NO;
    [self cancelTest:resumePercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = YES;
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    __block BOOL isSuccess = NO;
    QNUploadOption *resumeOption = [[QNUploadOption alloc] initWithMime:option.mimeType progressHandler:^(NSString *key, float percent) {
        float minPercent = 0;
        if (config.useConcurrentResumeUpload) {
            minPercent = percent - (config.chunkSize) * config.concurrentTaskCount / tempFile.size;
        } else {
            minPercent = percent - config.chunkSize / tempFile.size;
        }
        if (resumePercent >= minPercent) {
            isSuccess = YES;
        }
        if (option.progressHandler) {
            option.progressHandler(key, percent);
        }
    } params:option.params checkCrc:option.checkCrc cancellationSignal:option.cancellationSignal];

    [self uploadFile:tempFile key:key config:config option:resumeOption complete:^(QNResponseInfo * _Nonnull i, NSString * _Nonnull k) {

        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    NSLog(@"responseInfo:%@", responseInfo);
    XCTAssert(responseInfo.isOK, @"Pass");
    XCTAssert(responseInfo.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
}


- (void)resumeUploadTest:(float)resumePercent data:(NSData *)data key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    [self cancelTest:resumePercent data:data key:key config:config option:option];
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    __block BOOL isSuccess = NO;
    QNUploadOption *resumeOption = [[QNUploadOption alloc] initWithMime:option.mimeType progressHandler:^(NSString *key, float percent) {
        float minPercent = 0;
        if (config.useConcurrentResumeUpload) {
            minPercent = percent - (config.chunkSize) * config.concurrentTaskCount / data.length;
        } else {
            minPercent = percent - config.chunkSize / data.length;
        }
        if (resumePercent >= minPercent) {
            isSuccess = YES;
        }
        if (option.progressHandler) {
            option.progressHandler(key, percent);
        }
    } params:option.params checkCrc:option.checkCrc cancellationSignal:option.cancellationSignal];

    [self uploadData:data key:key config:config option:resumeOption complete:^(QNResponseInfo * _Nonnull i, NSString * _Nonnull k) {

        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    XCTAssert(responseInfo.isOK, @"Pass");
    XCTAssert(responseInfo.reqId, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
}

@end
