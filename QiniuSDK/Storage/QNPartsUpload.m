//
//  QNPartsUpload.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNPartsUpload.h"
#import "QNZoneInfo.h"

#define kQNRecordFileInfoKey @"recordFileInfo"
#define kQNRecordZoneInfoKey @"recordZoneInfo"


@interface QNPartsUpload()

@property(nonatomic, strong)QNUploadFileInfo *uploadFileInfo;

@end
@implementation QNPartsUpload

- (void)prepareToUpload{
    [super prepareToUpload];
    [self recoveryUploadInfoFromRecord];
    
    if (self.uploadFileInfo == nil) {
        self.uploadFileInfo = [[QNUploadFileInfo alloc] initWithFileSize:[self.file size]
                                                               blockSize:4 * 1024 * 1024
                                                                dataSize:self.config.chunkSize
                                                              modifyTime:(NSInteger)[self.file modifyTime]];
    }
}


- (void)switchRegionAndUpload{
    
    [self.uploadFileInfo clearUploadState];
    [self removeUploadInfoRecord];
    [super switchRegionAndUpload];
}


- (void)recordUploadInfo{
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }
    NSDictionary *zoneInfo = [[self getCurrentRegion] zonesInfo].detailInfo;
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
    if (self.recorder == nil) {
        return;
    }
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
    
    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:info[kQNRecordZoneInfoKey]];
    QNUploadFileInfo *fileInfo = [QNUploadFileInfo infoFromDictionary:info[kQNRecordFileInfoKey]];
    if (zoneInfo && fileInfo) {
        [self insertRegionAtFirstByZoneInfo:zoneInfo];
        self.uploadFileInfo = fileInfo;
    } else {
        [self.recorder del:self.key];
    }
}

@end
