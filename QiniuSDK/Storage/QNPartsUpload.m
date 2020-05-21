//
//  QNPartsUpload.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNPartsUpload.h"
#import "QNZoneInfo.h"
#import "QNReportItem.h"

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

- (void)prepareToUpload{
    [super prepareToUpload];
    [self recoveryUploadInfoFromRecord];
    
    if (self.uploadFileInfo == nil) {
        self.uploadFileInfo = [[QNUploadFileInfo alloc] initWithFileSize:[self.file size]
                                                               blockSize:[QNPartsUpload blockSize]
                                                                dataSize:[self getUploadChunkSize]
                                                              modifyTime:(NSInteger)[self.file modifyTime]];
    }
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

- (void)complete:(QNResponseInfo *)info resp:(NSDictionary *)resp{
    [self reportBlock];
    [super complete:info resp:resp];
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

- (void)recoveryUploadInfoFromRecord{
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
    NSLog(@"Reupload revovr info: %@", info);
    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:info[kQNRecordZoneInfoKey]];
    QNUploadFileInfo *fileInfo = [QNUploadFileInfo infoFromDictionary:info[kQNRecordFileInfoKey]];
    self.recoveredFrom = @(fileInfo.progress * fileInfo.size);
    if (zoneInfo && fileInfo && fileInfo.uploadBlocks.firstObject.size != [self getUploadChunkSize]) {
        [self insertRegionAtFirstByZoneInfo:zoneInfo];
        self.uploadFileInfo = fileInfo;
    } else {
        [self.recorder del:self.key];
    }
}

- (long long)getUploadChunkSize{
    if (self.chunkSize) {
        return self.chunkSize.longLongValue;
    } else {
        return self.config.chunkSize;
    }
}

//MARK:-- 统计block日志
- (void)reportBlock{
    
    QNUploadRegionRequestMetrics *metrics = self.currentRegionRequestMetrics ?: [QNUploadRegionRequestMetrics emptyMetrics];
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeBlock forKey:QNReportBlockKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportBlockKeyUpTime];
    [item setReportValue:[self getTargetRegion].zoneInfo.zoneRegionId forKey:QNReportBlockKeyTargetRegionId];
    [item setReportValue:[self getCurrentRegion].zoneInfo.zoneRegionId forKey:QNReportBlockKeyCurrentRegionId];
    [item setReportValue:metrics.totalElaspsedTime forKey:QNReportBlockKeyTotalElaspsedTime];
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
