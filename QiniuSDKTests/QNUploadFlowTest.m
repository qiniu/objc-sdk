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

- (void)allFileTypeCancelTest:(long long)cancelBytes
                     tempFile:(QNTempFile *)tempFile
                          key:(NSString *)key
                       config:(QNConfiguration *)config
                       option:(QNUploadOption *)option {
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    tempFile.fileType = QNTempFileTypeData;
    [self cancelTest:cancelBytes tempFile:tempFile key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeFile;
    [self cancelTest:cancelBytes tempFile:tempFile key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeStream;
    [self cancelTest:cancelBytes tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeStreamNoSize;
    [self cancelTest:cancelBytes tempFile:tempFile key:key config:config option:option];
}

- (void)cancelTest:(long long)cancelBytes tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    if (!option) {
        option = self.defaultOption;
    }
    
    __block BOOL cancelFlag = NO;
    QNUploadOption *cancelOption = [[QNUploadOption alloc] initWithMime:nil byteProgressHandler:^(NSString *key, long long uploadBytes, long long totalBytes) {
        if (cancelBytes <= uploadBytes) {
            cancelFlag = YES;
        }
        if (option.progressHandler) {
            option.progressHandler(key, uploadBytes*1.0/totalBytes);
        }
        if (option.byteProgressHandler) {
            option.byteProgressHandler(key, uploadBytes, totalBytes);
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
    XCTAssertTrue(responseInfo.isCancelled || responseInfo.isOK, @"response info:%@", responseInfo);
}

//MARK: ----- 断点续传
- (void)allFileTypeResumeUploadTest:(long long)resumeSize
                           tempFile:(QNTempFile *)tempFile
                                key:(NSString *)key
                             config:(QNConfiguration *)config
                             option:(QNUploadOption *)option {
    
    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    tempFile.fileType = QNTempFileTypeFile;
    [self resumeUploadTest:resumeSize tempFile:tempFile key:key config:config option:option];
    
    tempFile.fileType = QNTempFileTypeStream;
    [self resumeUploadTest:resumeSize tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    tempFile.fileType = QNTempFileTypeStreamNoSize;
    [self resumeUploadTest:resumeSize tempFile:tempFile key:key config:config option:option];
}

- (void)resumeUploadTest:(long long)resumeSize tempFile:(QNTempFile *)tempFile key:(NSString *)key config:(QNConfiguration *)config option:(QNUploadOption *)option {
    
    if (!option) {
        option = self.defaultOption;
    }

    BOOL canRemove = tempFile.canRemove;
    tempFile.canRemove = false;
    [self cancelTest:resumeSize tempFile:tempFile key:key config:config option:option];
    
    tempFile.canRemove = canRemove;
    __block QNResponseInfo *responseInfo = nil;
    __block NSString *keyUp = nil;
    __block BOOL isSuccess = NO;
    QNUploadOption *resumeOption = [[QNUploadOption alloc] initWithMime:option.mimeType byteProgressHandler:^(NSString *key, long long uploadBytes, long long totalBytes) {
        if (uploadBytes > 100) {
            isSuccess = YES;
        }
        if (option.progressHandler && totalBytes > 0) {
            option.progressHandler(key, uploadBytes*1.0/totalBytes);
        } else {
            NSLog(@"== key:%@ byte sent:%lld", key, uploadBytes);
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
    
    NSArray *upList01 = @[@"uptemp01.qbox.me"];
    QNZoneInfo *zoneInfo01 = [QNZoneInfo zoneInfoWithMainHosts:upList01 regionId:nil];
    
    NSArray *upList02 = @[@"upload.qiniup.com"];
    QNZoneInfo *zoneInfo02 = [QNZoneInfo zoneInfoWithMainHosts:upList02 regionId:nil];
    
    NSArray *upList03 = @[@"upload-na0.qiniup.com", @"up-na0.qbox.me"];
    QNZoneInfo *zoneInfo03 = [QNZoneInfo zoneInfoWithMainHosts:upList03 regionId:nil];
    QNZonesInfo *zonesInfo = [[QNZonesInfo alloc] initWithZonesInfo:@[zoneInfo01, zoneInfo02, zoneInfo03]];
    
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
