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

@property(nonatomic, strong)QNResponseInfo *uploadDataErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadDataErrorResponse;

@end
@implementation QNPartsUpload

- (void)initData {
    [super initData];
    // 根据文件从本地恢复上传信息，如果没有则重新构建上传信息
    if (self.config.resumeUploadVersion == QNResumeUploadVersionV1) {
        self.uploadPerformer = [[QNPartsUploadPerformerV1 alloc] initWithFile:self.file
                                                                     fileName:self.fileName
                                                                          key:self.key
                                                                        token:self.token
                                                                       option:self.option
                                                                configuration:self.config
                                                                  recorderKey:self.recorderKey];
    } else {
        self.uploadPerformer = [[QNPartsUploadPerformerV2 alloc] initWithFile:self.file
                                                                     fileName:self.fileName
                                                                          key:self.key
                                                                        token:self.token
                                                                       option:self.option
                                                                configuration:self.config
                                                                  recorderKey:self.recorderKey];
    }
}

- (BOOL)isAllUploaded {
    return [self.uploadPerformer.fileInfo isAllUploaded];
}

- (void)setErrorResponseInfo:(QNResponseInfo *)responseInfo errorResponse:(NSDictionary *)response{
    if (!responseInfo) {
        return;
    }
    if (!self.uploadDataErrorResponseInfo || responseInfo.statusCode != kQNSDKInteriorError) {
        self.uploadDataErrorResponseInfo = responseInfo;
        self.uploadDataErrorResponse = response ?: responseInfo.responseDictionary;
    }
}

- (int)prepareToUpload{
    int code = [super prepareToUpload];
    if (code != 0) {
        return code;
    }
    
    // 配置当前region
    if (self.uploadPerformer.currentRegion && self.uploadPerformer.currentRegion.isValid) {
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

- (BOOL)switchRegion{
    BOOL isSuccess = [super switchRegion];
    [self.uploadPerformer switchRegion:self.getCurrentRegion];
    return isSuccess;
}

- (BOOL)switchRegionAndUpload{
    [self reportBlock];
    return [super switchRegionAndUpload];;
}

// 根据错误信息进行切换region并上传，return:是否切换region并上传
- (BOOL)switchRegionAndUploadIfNeededWithErrorResponse:(QNResponseInfo *)errorResponseInfo {
    if (!errorResponseInfo || errorResponseInfo.isOK || // 不存在 || 不是error 不切
        !errorResponseInfo.couldRetry || ![self.config allowBackupHost] ||  // 不能重试不切
        ![self switchRegionAndUpload]) { // 切换失败
        return NO;
    }

    return YES;
}

- (void)startToUpload{
    [super startToUpload];

    // 重置错误信息
    self.uploadDataErrorResponseInfo = nil;
    self.uploadDataErrorResponse = nil;
    
    kQNWeakSelf;
    // 1. 启动upload
    [self serverInit:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        if (!responseInfo.isOK) {
            if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                [self complete:responseInfo response:response];
            }
            return;
        }
        
        // 2. 上传数据
        [self uploadRestData:^{
            if (![self isAllUploaded]) {
                if (![self switchRegionAndUploadIfNeededWithErrorResponse:self.uploadDataErrorResponseInfo]) {
                    [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                }
                return;
            }
            
            // 3. 组装文件
            [self completeUpload:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {

                if (!responseInfo.isOK) {
                    if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                        [self complete:responseInfo response:response];
                    }
                    return;
                }

                QNAsyncRunInMain(^{
                    self.option.progressHandler(self.key, 1.0);
                 });
                [self.uploadPerformer removeUploadInfoRecord];
                [self complete:responseInfo response:response];
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
    [item setReportValue:self.uploadPerformer.recoveredFrom forKey:QNReportBlockKeyRecoveredFrom];
    [item setReportValue:@(self.file.size) forKey:QNReportBlockKeyFileSize];
    [item setReportValue:@([QNUtils getCurrentProcessID]) forKey:QNReportBlockKeyPid];
    [item setReportValue:@([QNUtils getCurrentThreadID]) forKey:QNReportBlockKeyTid];
    [item setReportValue:@(1) forKey:QNReportBlockKeyUpApiVersion];
    [item setReportValue:[QNUtils getCurrentNetworkType] forKey:QNReportBlockKeyClientTime];
    
    [kQNReporter reportItem:item token:self.token.token];
}

@end
