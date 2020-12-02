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

@end
@implementation QNPartsUpload

+ (long long)blockSize{
    return 4 * 1024 * 1024;
}

- (void)initData {
    [super initData];
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

- (int)prepareToUpload{
    int code = [super prepareToUpload];
    if (code != 0) {
        return code;
    }
    
    if (self.uploadPerformer.currentRegion) {
        [self insertRegionAtFirst:self.uploadPerformer.currentRegion];
    }
    
    self.uploadPerformer.targetRegion = [self getTargetRegion];
    // currentRegion有的值为断点续传 就不用切
    if (!self.uploadPerformer.currentRegion) {
        [self.uploadPerformer switchRegion:[self getCurrentRegion]];
    }
    
    if (self.file == nil) {
        code = kQNLocalIOError;
    }
    return code;
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

- (void)uploadNextDataCompleteHandler:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler {
    
    kQNWeakSelf;
    void(^completeHandlerP)(QNResponseInfo *, QNUploadRegionRequestMetrics *, NSDictionary *) = ^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response){
        kQNStrongSelf;
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
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
