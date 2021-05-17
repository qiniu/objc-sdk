//
//  QNPartsUpload.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNUtils.h"
#import "QNLogUtil.h"
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
        QNLogInfo(@"key:%@ 分片V1", self.key);
        self.uploadPerformer = [[QNPartsUploadPerformerV1 alloc] initWithSource:self.uploadSource
                                                                       fileName:self.fileName
                                                                            key:self.key
                                                                          token:self.token
                                                                         option:self.option
                                                                  configuration:self.config
                                                                    recorderKey:self.recorderKey];
    } else {
        QNLogInfo(@"key:%@ 分片V2", self.key);
        self.uploadPerformer = [[QNPartsUploadPerformerV2 alloc] initWithSource:self.uploadSource
                                                                       fileName:self.fileName
                                                                            key:self.key
                                                                          token:self.token
                                                                         option:self.option
                                                                  configuration:self.config
                                                                    recorderKey:self.recorderKey];
    }
}

- (BOOL)isAllUploaded {
    return [self.uploadPerformer.uploadInfo isAllUploaded];
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
        QNLogInfo(@"key:%@ 使用缓存region", self.key);
    } else {
        // currentRegion无值 切换region
        [self.uploadPerformer switchRegion:[self getCurrentRegion]];
    }
    QNLogInfo(@"key:%@ region:%@", self.key, self.uploadPerformer.currentRegion.zoneInfo.regionId);
    
    if (self.uploadSource == nil) {
        code = kQNLocalIOError;
    }
    return code;
}

- (BOOL)switchRegion{
    BOOL isSuccess = [super switchRegion];
    if (isSuccess) {
        [self.uploadPerformer switchRegion:self.getCurrentRegion];
        QNLogInfo(@"key:%@ 切换region：%@", self.key , self.uploadPerformer.currentRegion.zoneInfo.regionId);
    }
    return isSuccess;
}

- (BOOL)switchRegionAndUpload{
    [self reportBlock];
    return [super switchRegionAndUpload];;
}

- (void)startToUpload{
    [super startToUpload];

    // 重置错误信息
    self.uploadDataErrorResponseInfo = nil;
    self.uploadDataErrorResponse = nil;
    
    
    QNLogInfo(@"key:%@ serverInit", self.key);
    
    // 1. 启动upload
    kQNWeakSelf;
    [self serverInit:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        if (!responseInfo.isOK) {
            if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                [self complete:responseInfo response:response];
            }
            return;
        }
        
        QNLogInfo(@"key:%@ uploadRestData", self.key);
        
        // 2. 上传数据
        kQNWeakSelf;
        [self uploadRestData:^{
            kQNStrongSelf;
            
            if (![self isAllUploaded]) {
                if (![self switchRegionAndUploadIfNeededWithErrorResponse:self.uploadDataErrorResponseInfo]) {
                    [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                }
                return;
            }
            
            QNLogInfo(@"key:%@ completeUpload", self.key);
            
            // 3. 组装文件
            kQNWeakSelf;
            [self completeUpload:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
                kQNStrongSelf;
                                
                if (!responseInfo.isOK) {
                    if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                        [self complete:responseInfo response:response];
                    }
                    return;
                }

                QNAsyncRunInMain(^{
                    self.option.progressHandler(self.key, 1.0);
                 });
                [self complete:responseInfo response:response];
            }];
        }];
    }];
}

- (void)uploadRestData:(dispatch_block_t)completeHandler {
    QNLogInfo(@"key:%@ 串行分片", self.key);
    [self performUploadRestData:completeHandler];
}

- (void)performUploadRestData:(dispatch_block_t)completeHandler {
    if ([self isAllUploaded]) {
        completeHandler();
        return;
    }
    
    kQNWeakSelf;
    [self uploadNextData:^(BOOL stop, QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        if (stop || !responseInfo.isOK) {
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
        
        if (!responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
        }
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    };
    
    [self.uploadPerformer serverInit:completeHandlerP];
}

- (void)uploadNextData:(void(^)(BOOL stop, QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kQNWeakSelf;
    void(^completeHandlerP)(BOOL, QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(BOOL stop, QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kQNStrongSelf;
        
        if (!responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
        }
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(stop, responseInfo, response);
    };
    
    [self.uploadPerformer uploadNextData:completeHandlerP];
}

- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kQNWeakSelf;
    void(^completeHandlerP)(QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kQNStrongSelf;
        
        if (!responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
        }
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    };
    [self.uploadPerformer completeUpload:completeHandlerP];
}


- (void)complete:(QNResponseInfo *)info response:(NSDictionary *)response{
    [self reportBlock];
    [self.uploadSource close];
    if ([self shouldRemoveUploadInfoRecord:info]) {
        [self.uploadPerformer removeUploadInfoRecord];
    }
    [super complete:info response:response];
}

- (BOOL)shouldRemoveUploadInfoRecord:(QNResponseInfo *)info {
    return info.isOK || info.statusCode == 612 || info.statusCode == 614 || info.statusCode == 701;
}

//MARK:-- 统计block日志
- (void)reportBlock{
    
    QNUploadRegionRequestMetrics *metrics = self.currentRegionRequestMetrics ?: [QNUploadRegionRequestMetrics emptyMetrics];
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeBlock forKey:QNReportBlockKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportBlockKeyUpTime];
    [item setReportValue:self.token.bucket forKey:QNReportBlockKeyTargetBucket];
    [item setReportValue:self.key forKey:QNReportBlockKeyTargetKey];
    [item setReportValue:[self getTargetRegion].zoneInfo.regionId forKey:QNReportBlockKeyTargetRegionId];
    [item setReportValue:[self getCurrentRegion].zoneInfo.regionId forKey:QNReportBlockKeyCurrentRegionId];
    [item setReportValue:metrics.totalElapsedTime forKey:QNReportBlockKeyTotalElapsedTime];
    [item setReportValue:metrics.bytesSend forKey:QNReportBlockKeyBytesSent];
    [item setReportValue:self.uploadPerformer.recoveredFrom forKey:QNReportBlockKeyRecoveredFrom];
    [item setReportValue:@([self.uploadSource getSize]) forKey:QNReportBlockKeyFileSize];
    [item setReportValue:@([QNUtils getCurrentProcessID]) forKey:QNReportBlockKeyPid];
    [item setReportValue:@([QNUtils getCurrentThreadID]) forKey:QNReportBlockKeyTid];
    
    if (self.config.resumeUploadVersion == QNResumeUploadVersionV1) {
        [item setReportValue:@(1) forKey:QNReportBlockKeyUpApiVersion];
    } else {
        [item setReportValue:@(2) forKey:QNReportBlockKeyUpApiVersion];
    }
    
    [item setReportValue:[QNUtils getCurrentNetworkType] forKey:QNReportBlockKeyClientTime];
    [item setReportValue:[QNUtils systemName] forKey:QNReportBlockKeyOsName];
    [item setReportValue:[QNUtils systemVersion] forKey:QNReportBlockKeyOsVersion];
    [item setReportValue:[QNUtils sdkLanguage] forKey:QNReportBlockKeySDKName];
    [item setReportValue:[QNUtils sdkVersion] forKey:QNReportBlockKeySDKVersion];
    
    [kQNReporter reportItem:item token:self.token.token];
}

@end
