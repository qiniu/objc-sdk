//
//  QNPartsUploadPerformer.m
//  QiniuSDK
//
//  Created by yangsen on 2020/12/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNLogUtil.h"
#import "QNAsyncRun.h"
#import "QNUpToken.h"
#import "QNZoneInfo.h"
#import "QNUploadOption.h"
#import "QNConfiguration.h"
#import "QNUploadInfo.h"
#import "QNUploadRegionInfo.h"
#import "QNRecorderDelegate.h"
#import "QNUploadDomainRegion.h"
#import "QNPartsUploadPerformer.h"
#import "QNUpProgress.h"
#import "QNRequestTransaction.h"

#define kQNRecordFileInfoKey @"recordFileInfo"
#define kQNRecordZoneInfoKey @"recordZoneInfo"

@interface QNPartsUploadPerformer()

@property(nonatomic, assign) BOOL isRecording;

@property (nonatomic,   copy) NSString *key;
@property (nonatomic,   copy) NSString *fileName;
@property (nonatomic, strong) id <QNUploadSource> uploadSource;
@property (nonatomic, strong) QNUpToken *token;

@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy) NSString *recorderKey;

@property (nonatomic, strong) NSNumber *recoveredFrom;
@property (nonatomic, strong) id <QNUploadRegion> targetRegion;
@property (nonatomic, strong) id <QNUploadRegion> currentRegion;
@property (nonatomic, strong) QNUploadInfo *uploadInfo;

@property(nonatomic, strong) QNUpProgress *progress;
@property(nonatomic, strong) NSMutableArray <QNRequestTransaction *> *uploadTransactions;

@end
@implementation QNPartsUploadPerformer

- (instancetype)initWithSource:(id<QNUploadSource>)uploadSource
                      fileName:(NSString *)fileName
                           key:(NSString *)key
                         token:(QNUpToken *)token
                        option:(QNUploadOption *)option
                 configuration:(QNConfiguration *)config
                   recorderKey:(NSString *)recorderKey {
    if (self = [super init]) {
        _uploadSource = uploadSource;
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
    self.isRecording = NO;
    self.uploadTransactions = [NSMutableArray array];
    
    if (!self.uploadInfo) {
        self.uploadInfo = [self getDefaultUploadInfo];
    }
    [self recoverUploadInfoFromRecord];
}

- (BOOL)couldReloadInfo {
    return [self.uploadInfo couldReloadSource];
}

- (BOOL)reloadInfo {
    return [self.uploadInfo reloadSource];
}

- (void)switchRegion:(id <QNUploadRegion>)region {
    [self.uploadInfo clearUploadState];
    self.currentRegion = region;
    self.recoveredFrom = nil;
    if (!self.targetRegion) {
        self.targetRegion = region;
    }
}

- (void)notifyProgress:(BOOL)isCompleted {
    if (self.uploadInfo == nil) {
        return;
    }
    
    if (isCompleted) {
        [self.progress notifyDone:self.key totalBytes:[self.uploadInfo getSourceSize]];
    } else {
        [self.progress progress:self.key uploadBytes:[self.uploadInfo uploadSize] totalBytes:[self.uploadInfo getSourceSize]];
    }
}

- (void)recordUploadInfo {
    @synchronized (self) {
        if (self.isRecording) {
            return;
        }
        self.isRecording = YES;
    }
    
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || key.length == 0) {
        return;
    }
    NSDictionary *zoneInfo = [self.currentRegion zoneInfo].detailInfo;
    NSDictionary *uploadInfo = [self.uploadInfo toDictionary];
    if (zoneInfo && uploadInfo) {
        NSDictionary *info = @{kQNRecordZoneInfoKey : zoneInfo,
                               kQNRecordFileInfoKey : uploadInfo};
        NSData *data = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [self.recorder set:key data:data];
        }
    }
    QNLogInfo(@"key:%@ recorderKey:%@ recordUploadInfo", self.key, self.recorderKey);
    
    @synchronized (self) {
        self.isRecording = NO;
    }
}

- (void)removeUploadInfoRecord {
    
    self.recoveredFrom = nil;
    [self.uploadInfo clearUploadState];
    [self.recorder del:self.recorderKey];
    QNLogInfo(@"key:%@ recorderKey:%@ removeUploadInfoRecord", self.key, self.recorderKey);
}

- (void)recoverUploadInfoFromRecord {
    QNLogInfo(@"key:%@ recorderKey:%@ recorder:%@ recoverUploadInfoFromRecord", self.key, self.recorderKey, self.recorder);
    
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }

    NSData *data = [self.recorder get:key];
    if (data == nil) {
        QNLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord data:nil", self.key, self.recorderKey);
        return;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        QNLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord json error", self.key, self.recorderKey);
        [self.recorder del:self.key];
        return;
    }

    QNZoneInfo *zoneInfo = [QNZoneInfo zoneInfoFromDictionary:info[kQNRecordZoneInfoKey]];
    QNUploadInfo *recoverUploadInfo = [self getFileInfoWithDictionary:info[kQNRecordFileInfoKey]];
    
    if (zoneInfo && self.uploadInfo && [self.uploadInfo isValid]
        && [self.uploadInfo isSameUploadInfo:recoverUploadInfo]) {
        QNLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord valid", self.key, self.recorderKey);
        
        [recoverUploadInfo checkInfoStateAndUpdate];
        self.uploadInfo = recoverUploadInfo;
        
        QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
        [region setupRegionData:zoneInfo];
        self.currentRegion = region;
        self.targetRegion = region;
        self.recoveredFrom = @([recoverUploadInfo uploadSize]);
    } else {
        QNLogInfo(@"key:%@ recorderKey:%@ recoverUploadInfoFromRecord invalid", self.key, self.recorderKey);
        
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

- (QNUploadInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return nil;
}

- (QNUploadInfo *)getDefaultUploadInfo {
    return nil;
}

- (void)serverInit:(void (^)(QNResponseInfo * _Nullable,
                             QNUploadRegionRequestMetrics * _Nullable,
                             NSDictionary * _Nullable))completeHandler {}

- (void)uploadNextData:(void (^)(BOOL stop,
                                 QNResponseInfo * _Nullable,
                                 QNUploadRegionRequestMetrics * _Nullable,
                                 NSDictionary * _Nullable))completeHandler {}

- (void)completeUpload:(void (^)(QNResponseInfo * _Nullable,
                                 QNUploadRegionRequestMetrics * _Nullable,
                                 NSDictionary * _Nullable))completeHandler {}

- (QNUpProgress *)progress {
    if (_progress == nil) {
        _progress = [QNUpProgress progress:self.option.progressHandler byteProgress:self.option.byteProgressHandler];
    }
    return _progress;
}

@end
