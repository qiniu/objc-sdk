//
//  QNPartsUploadPerformer.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import "QNUpToken.h"
#import "QNZoneInfo.h"
#import "QNUploadOption.h"
#import "QNConfiguration.h"
#import "QNFileDelegate.h"
#import "QNUploadRegionInfo.h"
#import "QNRecorderDelegate.h"
#import "QNUploadDomainRegion.h"
#import "QNPartsUploadPerformer.h"
#import "QNRequestTransaction.h"

#define kQNRecordFileInfoKey @"recordFileInfo"
#define kQNRecordZoneInfoKey @"recordZoneInfo"

@interface QNPartsUploadPerformer()

@property (nonatomic,   copy) NSString *key;
@property (nonatomic,   copy) NSString *fileName;
@property (nonatomic, strong) id <QNFileDelegate> file;
@property (nonatomic, strong) QNUpToken *token;

@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy) NSString *recorderKey;

@property (nonatomic, strong) NSNumber *recoveredFrom;
@property (nonatomic, strong) id <QNUploadRegion> targetRegion;
@property (nonatomic, strong) id <QNUploadRegion> currentRegion;
@property (nonatomic, strong) QNUploadFileInfo *fileInfo;

@property(nonatomic, assign) CGFloat previousPercent;
@property(nonatomic, strong)NSMutableArray <QNRequestTransaction *> *uploadTransactions;

@end
@implementation QNPartsUploadPerformer

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                    fileName:(NSString *)fileName
                         key:(NSString *)key
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
                 recorderKey:(NSString *)recorderKey {
    if (self = [super init]) {
        _file = file;
        _fileName = fileName;
        _key = key;
        _token = token;
        _option = option;
        _config = config;
        _recorder = config.recorder;
        _recorderKey = recorderKey;
        
        [self initData];
    }
    return self;
}

- (void)initData {
    self.uploadTransactions = [NSMutableArray array];
    
    [self recoverUploadInfoFromRecord];
    if (!self.fileInfo) {
        self.fileInfo = [self getDefaultUploadFileInfo];
    }
}

- (void)switchRegion:(id <QNUploadRegion>)region {
    [self.fileInfo clearUploadState];
    self.currentRegion = region;
    self.recoveredFrom = nil;
    if (!self.targetRegion) {
        self.targetRegion = region;
    }
}

- (void)notifyProgress {
    float percent = self.fileInfo.progress;
    if (percent > 0.95) {
        percent = 0.95;
    }
    if (percent > self.previousPercent) {
        self.previousPercent = percent;
    } else {
        percent = self.previousPercent;
    }
    QNAsyncRunInMain(^{
        self.option.progressHandler(self.key, percent);
    });
}

- (void)recordUploadInfo {
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || key.length == 0) {
        return;
    }
    NSDictionary *zoneInfo = [self.currentRegion zoneInfo].detailInfo;
    NSDictionary *fileInfo = [self.fileInfo toDictionary];
    if (zoneInfo && fileInfo) {
        NSDictionary *info = @{kQNRecordZoneInfoKey : zoneInfo,
                               kQNRecordFileInfoKey : fileInfo};
        NSData *data = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [self.recorder set:key data:data];
        }
    }
}

- (void)removeUploadInfoRecord {
    
    self.recoveredFrom = nil;
    [self.fileInfo clearUploadState];
    [self.recorder del:self.recorderKey];
}

- (void)recoverUploadInfoFromRecord {
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
    QNUploadFileInfo *fileInfo = [self getFileInfoWithDictionary:info[kQNRecordFileInfoKey]];
    
    if (zoneInfo && fileInfo && ![fileInfo isEmpty]
        && fileInfo.size == self.file.size && fileInfo.modifyTime == self.file.modifyTime) {
        
        self.fileInfo = fileInfo;
        
        QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
        [region setupRegionData:zoneInfo];
        self.currentRegion = region;
        self.targetRegion = region;
        self.recoveredFrom = @(fileInfo.progress * fileInfo.size);
    } else {
        [self.recorder del:self.key];
        self.currentRegion = nil;
        self.targetRegion = nil;
        self.recoveredFrom = nil;
    }
}

- (QNRequestTransaction *)createUploadRequestTransaction {
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithConfig:self.config
                                                                        uploadOption:self.option
                                                                        targetRegion:self.targetRegion
                                                                       currentRegion:self.currentRegion
                                                                                 key:self.key
                                                                               token:self.token];
    @synchronized (self) {
        [self.uploadTransactions addObject:transaction];
    }
    return transaction;
}

- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction {
    if (transaction) {
        @synchronized (self) {
            [self.uploadTransactions removeObject:transaction];
        }
    }
}

- (QNUploadFileInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return nil;
}

- (QNUploadFileInfo *)getDefaultUploadFileInfo {
    return nil;
}

- (void)serverInit:(void (^)(QNResponseInfo * _Nullable,
                             QNUploadRegionRequestMetrics * _Nullable,
                             NSDictionary * _Nullable))completeHandler {}

- (void)uploadNextDataCompleteHandler:(void (^)(BOOL stop,
                                                QNResponseInfo * _Nullable,
                                                QNUploadRegionRequestMetrics * _Nullable,
                                                NSDictionary * _Nullable))completeHandler {}

- (void)completeUpload:(void (^)(QNResponseInfo * _Nullable,
                                 QNUploadRegionRequestMetrics * _Nullable,
                                 NSDictionary * _Nullable))completeHandler {}

@end
