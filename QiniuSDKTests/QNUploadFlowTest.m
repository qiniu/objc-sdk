//
//  QNUploadFlowTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"
#import "QNUploadFlowTest.h"

@implementation QNUploadFlowTest

- (void)allFileTypeCancelTest:(float)cancelPercent
                     tempFile:(QNTempFile *)tempFile
                          key:(NSString *)key
                       config:(QNConfiguration *)config
                       option:(QNUploadOption *)option {
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    tempFile.fileType = QNTempFileTypeData;
    [self cancelTest:cancelPercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeFile;
    [self cancelTest:cancelPercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeStream;
    [self cancelTest:cancelPercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeStreamNoSize;
    [self cancelTest:cancelPercent tempFile:tempFile key:key config:config option:option];
}

- (void)cancelTest:(float)cancelPercent tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    if (!option) {
        option = self.defaultOption;
    }
    
    __block BOOL cancelFlag = NO;
    QNUploadOption *cancelOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        if (cancelPercent <= percent) {
            cancelFlag = YES;
        }
        if (option.progressHandler) {
            option.progressHandler(key, percent);
        }
    }
        params:option.params
        checkCrc:option.checkCrc
        cancellationSignal:^BOOL() {
            return cancelFlag;
        }];
    
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    [self upload:tempFile key:key config:config option:cancelOption complete:^(QNResponseInfo *i, NSString *k) {
        
        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    NSLog(@"responseInfo:%@", responseInfo);
    XCTAssertTrue(responseInfo.isCancelled, @"response info:%@", responseInfo);
}

//MARK: ----- 断点续传
- (void)allFileTypeResumeUploadTest:(float)resumePercent
                           tempFile:(QNTempFile *)tempFile
                                key:(NSString *)key
                             config:(QNConfiguration *)config
                             option:(QNUploadOption *)option {
    
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    tempFile.fileType = QNTempFileTypeData;
    [self resumeUploadTest:resumePercent tempFile:tempFile key:key config:config option:option];

    tempFile.fileType = QNTempFileTypeFile;
    [self resumeUploadTest:resumePercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeStream;
    [self resumeUploadTest:resumePercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeStreamNoSize;
    [self resumeUploadTest:resumePercent tempFile:tempFile key:key config:config option:option];
}

- (void)resumeUploadTest:(float)resumePercent tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    if (!option) {
        option = self.defaultOption;
    }
    
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    [self cancelTest:resumePercent tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    __block BOOL isSuccess = NO;
    QNUploadOption *resumeOption = [[QNUploadOption alloc] initWithMime:option.mimeType progressHandler:^(NSString *key, float percent) {
        float minPercent = 0;
        float currentChunkCount = 0;
        float chunkSize = 0;
        if (!config.useConcurrentResumeUpload) {
            currentChunkCount = 1;
            chunkSize = config.chunkSize;
        } else if (config.resumeUploadVersion == QNResumeUploadVersionV1) {
            currentChunkCount = config.concurrentTaskCount;
            chunkSize = 4 * 1024 * 1024;
        } else {
            currentChunkCount = config.concurrentTaskCount;
            chunkSize = config.chunkSize;
        }
        minPercent = percent + currentChunkCount * chunkSize / [tempFile size];
        
        if (resumePercent <= minPercent) {
            isSuccess = YES;
        }
        if (option.progressHandler) {
            option.progressHandler(key, percent);
        }
    } params:option.params checkCrc:option.checkCrc cancellationSignal:option.cancellationSignal];

    [self upload:tempFile key:key config:config option:resumeOption complete:^(QNResponseInfo * _Nonnull i, NSString * _Nonnull k) {

        responseInfo = i;
        keyUp = k;
    }];
    
    AGWW_WAIT_WHILE(!responseInfo, 60 * 30);
    NSLog(@"responseInfo:%@", responseInfo);
    XCTAssertTrue(isSuccess, @"response info:%@", responseInfo);
    XCTAssertTrue(responseInfo.isOK, @"response info:%@", responseInfo);
    XCTAssertTrue(responseInfo.reqId, @"response info:%@", responseInfo);
}


//MARK: ----- 切换Region
- (void)allFileTypeSwitchRegionTestWithFile:(QNTempFile *)tempFile
                                        key:(NSString *)key
                                     config:(QNConfiguration *)config
                                     option:(QNUploadOption *)option {
    
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    [self switchRegionTestWithFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeFile;
    [self switchRegionTestWithFile:tempFile key:key config:config option:option];
}

- (void)switchRegionTestWithFile:(QNTempFile *)tempFile
                             key:(NSString *)key
                          config:(QNConfiguration *)config
                          option:(QNUploadOption *)option {
    
    NSArray *upList01 = @[@"uptemp01.qbox.me", @"uptemp02.qbox.me"];
    QNZoneInfo *zoneInfo01 = [QNZoneInfo zoneInfoWithMainHosts:upList01 regionId:nil];
    
    NSArray *upList02 = @[@"upload-na0.qiniup.com", @"up-na0.qbox.me"];
    QNZoneInfo *zoneInfo02 = [QNZoneInfo zoneInfoWithMainHosts:upList02 regionId:nil];
    QNZonesInfo *zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:@[zoneInfo01, zoneInfo02]];
    
    QNFixedZone *zone = [[QNFixedZone alloc] init];
    [zone setValue:zonesInfo forKeyPath:@"zonesInfo"];
    
    QNConfiguration *switchConfig = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.chunkSize = config.chunkSize;
        builder.putThreshold = config.putThreshold;
        builder.retryMax = config.retryMax;
        builder.timeoutInterval = config.timeoutInterval;
        builder.retryInterval = config.retryInterval;
        builder.recorder = config.recorder;
        builder.recorderKeyGen = config.recorderKeyGen;
        builder.proxy = config.proxy;
        builder.converter = config.converter;
        builder.useHttps = config.useHttps;
        builder.allowBackupHost = config.allowBackupHost;
        builder.useConcurrentResumeUpload = config.useConcurrentResumeUpload;
        builder.resumeUploadVersion = config.resumeUploadVersion;
        builder.concurrentTaskCount = config.concurrentTaskCount;

        builder.zone = zone;
    }];
    [self uploadAndAssertSuccessResult:tempFile key:key config:switchConfig option:option];

}

@end
