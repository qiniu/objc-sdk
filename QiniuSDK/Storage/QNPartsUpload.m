//
//  QNPartsUpload.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNUtils.h"
#import "QNPartsUpload.h"
#import "QNZoneInfo.h"
#import "QNReportItem.h"
#import "QNRequestTransaction.h"
#import "QNPartsUploadPerformerV1.h"
#import "QNPartsUploadPerformerV2.h"

#define kQNRecordFileInfoKey @"recordFileInfo"
#define kQNRecordZoneInfoKey @"recordZoneInfo"


@interface QNPartsUpload()

@property(nonatomic, strong)QNPartsUploadPerformer *uploadPerformer;
@property(nonatomic, strong)NSNumber *recoveredFrom; // 断点续传时，起始上传偏移
@property(nonatomic, strong)QNUploadFileInfo *uploadFileInfo;

@property(nonatomic, strong)QNResponseInfo *uploadDataErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadDataErrorResponse;

@end
@implementation QNPartsUpload

+ (long long)blockSize{
    return 4 * 1024 * 1024;
}

- (void)initData {
    [super initData];
    // 根据文件从本地恢复上传信息，如果没有则重新构建上传信息
    if (self.config.resumeUploadVersion == QNResumeUploadVersionV2) {
        self.uploadPerformer = [[QNPartsUploadPerformerV2 alloc] initWithFile:self.file
                                                                     fileName:self.fileName
                                                                          key:self.key
                                                                        token:self.token
                                                                       option:self.option
                                                                configuration:self.config
                                                                  recorderKey:self.recorderKey];
    } else {
        self.uploadPerformer = [[QNPartsUploadPerformerV1 alloc] initWithFile:self.file
                                                                     fileName:self.fileName
                                                                          key:self.key
                                                                        token:self.token
                                                                       option:self.option
                                                                configuration:self.config
                                                                  recorderKey:self.recorderKey];
    }
}

- (BOOL)switchRegionAndUpload{
    [self reportBlock];
    
    BOOL isSwitched = [super switchRegionAndUpload];
    if (isSwitched) {
        [self.uploadPerformer switchRegion:self.getCurrentRegion];
    }
    return isSwitched;
}

- (BOOL)isAllUploaded {
    return [self.uploadPerformer.fileInfo isAllUploaded];
}

- (void)setErrorResponseInfo:(QNResponseInfo *)responseInfo errorResponse:(NSDictionary *)response{
    if (!responseInfo) {
        return;
    }
    if (!self.uploadDataErrorResponseInfo
        || (responseInfo.statusCode == kQNNoUsableHostError)) {
        self.uploadDataErrorResponseInfo = responseInfo;
        self.uploadDataErrorResponse = response ?: responseInfo.responseDictionary;
    }
}

- (int)prepareToUpload{
    int code = [super prepareToUpload];
    if (code != 0) {
        return code;
    }
    // 重置错误信息
    self.uploadDataErrorResponseInfo = nil;
    self.uploadDataErrorResponse = nil;
    
    // 配置目标region
    self.uploadPerformer.targetRegion = [self getTargetRegion];
    // 配置当前region
    if (self.uploadPerformer.currentRegion) {
        // currentRegion有值，为断点续传，将region插入至regionList第一处
        [self insertRegionAtFirst:self.uploadPerformer.currentRegion];
    } else {
        // currentRegion无值 切换region
        [self.uploadPerformer switchRegion:[self getCurrentRegion]];
    }
    
    if (self.file == nil) {
        code = kQNLocalIOError;
    }
    return code;
}

- (void)startToUpload{
    [super startToUpload];

    kQNWeakSelf;
    // 1. 启动upload
    [self serverInit:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        if (!responseInfo.isOK) {
            [self complete:responseInfo response:response];
            return;
        }
        
        // 2. 上传数据
        [self uploadRestData:^{
            if (![self isAllUploaded]) {
                if (self.uploadDataErrorResponseInfo.couldRetry && [self.config allowBackupHost]) {
                    BOOL isSwitched = [self switchRegionAndUpload];
                    if (isSwitched == NO) {
                        [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                    }
                } else {
                    [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                }
                return;
            }
            
            // 3. 组装文件
            [self completeUpload:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {

                if (responseInfo.isOK == NO) {
                    if (responseInfo.couldRetry && [self.config allowBackupHost]) {
                        BOOL isSwitched = [self switchRegionAndUpload];
                        if (isSwitched == NO) {
                            [self complete:responseInfo response:response];
                        }
                    } else {
                        [self complete:responseInfo response:response];
                    }
                } else {
                    QNAsyncRunInMain(^{
                        self.option.progressHandler(self.key, 1.0);
                     });
                    [self complete:responseInfo response:response];
                }
            }];
        }];
    }];
}

- (void)uploadRestData:(dispatch_block_t)completeHandler {
    
    [self performUploadRestData:completeHandler];
}

- (void)performUploadRestData:(dispatch_block_t)completeHandler {
    if ([self isAllUploaded]) {
        completeHandler();
        return;
    }
    
    [self uploadNextDataCompleteHandler:^(BOOL stop, QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        if (stop || !responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
            completeHandler();
        } else {
            [self performUploadRestData:completeHandler];
        }
    }];
}

//MARK:-- concurrent upload model API
- (void)serverInit:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kQNWeakSelf;
    void(^completeHandlerP)(QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kQNStrongSelf;
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    };
    
    [self.uploadPerformer serverInit:completeHandlerP];
}

- (void)uploadNextDataCompleteHandler:(void(^)(BOOL stop, QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kQNWeakSelf;
    void(^completeHandlerP)(BOOL, QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(BOOL stop, QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kQNStrongSelf;
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(stop, responseInfo, response);
    };
    
    [self.uploadPerformer uploadNextDataCompleteHandler:completeHandlerP];
}

- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kQNWeakSelf;
    void(^completeHandlerP)(QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kQNStrongSelf;
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    };
    [self.uploadPerformer completeUpload:completeHandlerP];
}


- (void)complete:(QNResponseInfo *)info response:(NSDictionary *)response{
    [self reportBlock];
    [self.file close];
    [super complete:info response:response];
}

//MARK:-- 统计block日志
- (void)reportBlock{
    
    QNUploadRegionRequestMetrics *metrics = self.currentRegionRequestMetrics ?: [QNUploadRegionRequestMetrics emptyMetrics];
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeBlock forKey:QNReportBlockKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportBlockKeyUpTime];
    [item setReportValue:[self getTargetRegion].zoneInfo.regionId forKey:QNReportBlockKeyTargetRegionId];
    [item setReportValue:[self getCurrentRegion].zoneInfo.regionId forKey:QNReportBlockKeyCurrentRegionId];
    [item setReportValue:metrics.totalElapsedTime forKey:QNReportBlockKeyTotalElapsedTime];
    [item setReportValue:metrics.bytesSend forKey:QNReportBlockKeyBytesSent];
    [item setReportValue:self.recoveredFrom forKey:QNReportBlockKeyRecoveredFrom];
    [item setReportValue:@(self.file.size) forKey:QNReportBlockKeyFileSize];
    [item setReportValue:@([QNUtils getCurrentProcessID]) forKey:QNReportBlockKeyPid];
    [item setReportValue:@([QNUtils getCurrentThreadID]) forKey:QNReportBlockKeyTid];
    [item setReportValue:@(1) forKey:QNReportBlockKeyUpApiVersion];
    [item setReportValue:[QNUtils getCurrentNetworkType] forKey:QNReportBlockKeyClientTime];
    
    [kQNReporter reportItem:item token:self.token.token];
}

@end
