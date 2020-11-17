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

#define kQNRecordFileInfoKey @"recordFileInfo"
#define kQNRecordZoneInfoKey @"recordZoneInfo"


@interface QNPartsUpload()

@property(nonatomic, strong)NSNumber *recoveredFrom; // 断点续传时，起始上传偏移
@property(nonatomic, strong)QNUploadFileInfo *uploadFileInfo;

@end
@implementation QNPartsUpload

+ (long long)blockSize{
    return 4 * 1024 * 1024;
}

- (int)prepareToUpload{
    int code = [super prepareToUpload];
    if (code != 0) {
        return code;
    }
    
    [self recoverUploadInfoFromRecord:self.file];
    if (self.uploadFileInfo == nil) {
        self.uploadFileInfo = [[QNUploadFileInfo alloc] initWithFileSize:[self.file size]
                                                                dataSize:[self getUploadChunkSize]
                                                              modifyTime:(NSInteger)[self.file modifyTime]];
    }
    if (self.file == nil) {
        code = kQNLocalIOError;
    }
    return code;
}


- (BOOL)switchRegionAndUpload{
    [self reportBlock];
    [self.uploadFileInfo clearUploadState];
    
    BOOL isSwitched = [super switchRegionAndUpload];
    if (isSwitched) {
        [self removeUploadInfoRecord];
    }
    return isSwitched;
}

- (void)complete:(QNResponseInfo *)info response:(NSDictionary *)response{
    [self reportBlock];
    [self.file close];
    [super complete:info response:response];
}


- (void)recordUploadInfo{
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || key.length == 0) {
        return;
    }
    NSDictionary *zoneInfo = [[self getCurrentRegion] zoneInfo].detailInfo;
    NSDictionary *fileInfo = [self.uploadFileInfo toDictionary];
    if (zoneInfo && fileInfo) {
        NSDictionary *info = @{kQNRecordZoneInfoKey : zoneInfo,
                               kQNRecordFileInfoKey : fileInfo};
        NSData *data = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [self.recorder set:key data:data];
        }
    }
}

- (void)removeUploadInfoRecord{
    
    self.recoveredFrom = nil;
    [self.uploadFileInfo clearUploadState];
    [self.recorder del:self.recorderKey];
}

- (void)recoverUploadInfoFromRecord:(id <QNFileDelegate>)file{
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }

    NSData *data = [self.recorder get:key];
    if (data == nil) {
        return;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        [self.recorder del:self.key];
        return;
    }

    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:info[kQNRecordZoneInfoKey]];
    QNUploadFileInfo *fileInfo = [QNUploadFileInfo infoFromDictionary:info[kQNRecordFileInfoKey]];
    self.recoveredFrom = @(fileInfo.progress * fileInfo.size);
    if (zoneInfo && fileInfo && (fileInfo.size == [file size]) && (file.modifyTime == fileInfo.modifyTime)) {
        [self insertRegionAtFirstByZoneInfo:zoneInfo];
        self.uploadFileInfo = fileInfo;
    } else {
        [self.recorder del:self.key];
    }
}

- (long long)getUploadChunkSize{
    if (self.dataSize) {
        return self.dataSize.longLongValue;
    } else {
        return self.config.chunkSize;
    }
}

//MARK:-- concurrent upload model API
- (void)initPartToServer:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler{
    if (self.uploadFileInfo.uploadId
        && (self.uploadFileInfo.expireAt.integerValue - [[NSDate date] timeIntervalSince1970]) > 600) {
        QNResponseInfo *responseInfo = [QNResponseInfo successResponse];
        completeHandler(responseInfo, nil);
        return;
    }
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];

    kQNWeakSelf;
    [transaction initPart:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        NSString *uploadId = response[@"uploadId"];
        NSNumber *expireAt = response[@"expireAt"];
        if (responseInfo.isOK && uploadId && expireAt) {
            self.uploadFileInfo.uploadId = uploadId;
            self.uploadFileInfo.expireAt = expireAt;
            [self recordUploadInfo];
        }
        completeHandler(responseInfo, response);
    }];
}

- (void)uploadDataToServer:(QNUploadData *)data
                    progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
             completeHandler:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler{
    
    NSData *uploadData = [self getUploadData:data];
    if (data == nil) {
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithLocalIOError:@"get data error"];
        completeHandler(responseInfo, responseInfo.responseDictionary);
        return;
    }
    
    data.isUploading = YES;
    data.isCompleted = NO;
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction uploadPart:self.uploadFileInfo.uploadId
                  partIndex:data.index
                   partData:uploadData
                   progress:progress
                   complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
        
        [self destroyUploadRequestTransaction:transaction];
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        NSString *etag = response[@"etag"];
        NSString *md5 = response[@"md5"];
        if (responseInfo.isOK && etag && md5) {
            data.etag = etag;
            data.isUploading = NO;
            data.isCompleted = YES;
            [self recordUploadInfo];
        } else {
            data.isUploading = NO;
            data.isCompleted = NO;
        }
        completeHandler(responseInfo, response);
    }];
}

- (void)completePartsToServer:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))completeHandler{
    
    NSArray *partInfoArray = [self.uploadFileInfo getPartInfoArray];
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    [transaction completeParts:self.fileName uploadId:self.uploadFileInfo.uploadId partInfoArray:partInfoArray complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        
        [self addRegionRequestMetricsOfOneFlow:metrics];
        completeHandler(responseInfo, response);
    }];
    
}

- (QNRequestTransaction *)createUploadRequestTransaction{
    return nil;
}
- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction{
}

- (NSData *)getUploadData:(QNUploadData *)data{
    if (!self.file) {
        return nil;
    }
    return [self.file read:(long)data.offset
                      size:(long)data.size
                     error:nil];
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
