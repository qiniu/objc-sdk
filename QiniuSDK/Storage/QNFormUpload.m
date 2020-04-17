//
//  QNFormUpload.m
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNFormUpload.h"
#import "QNConfiguration.h"
#import "QNCrc32.h"
#import "QNRecorderDelegate.h"
#import "QNResponseInfo.h"
#import "QNUploadManager.h"
#import "QNUploadOption+Private.h"
#import "QNUrlSafeBase64.h"
#import "QNAsyncRun.h"
#import "QNUploadInfoCollector.h"

@interface QNFormUpload ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) QNSessionManager *sessionManager;
@property (nonatomic) int retryTimes;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpCompletionHandler complete;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic) float previousPercent;
@property (nonatomic, assign) QNZoneInfoType currentZoneType;
@property (nonatomic, strong) NSString *access; //AK
@property (nonatomic, copy) NSString *identifier;

@end

@implementation QNFormUpload

- (instancetype)initWithData:(NSData *)data
                     withKey:(NSString *)key
                withFileName:(NSString *)fileName
                   withToken:(QNUpToken *)token
              withIdentifier:(NSString *)identifier
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
            withSessionManager:(QNSessionManager *)sessionManager
           withConfiguration:(QNConfiguration *)config {
    if (self = [super init]) {
        _data = data;
        _key = key;
        _token = token;
        _option = option != nil ? option : [QNUploadOption defaultOptions];
        _complete = block;
        _sessionManager = sessionManager;
        _config = config;
        _fileName = fileName != nil ? fileName : @"?";
        _previousPercent = 0;
        _access = token.access;
        _currentZoneType = QNZoneInfoTypeMain;
        _identifier = identifier;
        
    }
    return self;
}

- (void)put {
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (_key) {
        parameters[@"key"] = _key;
    }
    parameters[@"token"] = _token.token;
    [parameters addEntriesFromDictionary:_option.params];
    parameters[@"crc32"] = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:_data]];
    
    [self nextTask:0 needDelay:NO host:[_config.zone up:_token zoneInfoType:_currentZoneType isHttps:_config.useHttps frozenDomain:nil] param:parameters];
}

- (void)nextTask:(int)retried needDelay:(BOOL)needDelay host:(NSString *)host param:(NSDictionary *)param {
    
    if (needDelay) {
        QNAsyncRunAfter(_config.retryInterval, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self nextTask:retried host:host param:param];
        });
    } else {
        [self nextTask:retried host:host param:param];
    }
}

- (void)nextTask:(int)retried host:(NSString *)host param:(NSDictionary *)param {
        
    QNInternalProgressBlock p = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        float percent = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        if (percent > 0.95) {
            percent = 0.95;
        }
        if (percent > self.previousPercent) {
            self.previousPercent = percent;
        } else {
            percent = self.previousPercent;
        }
        self.option.progressHandler(self.key, percent);
    };
    QNCompleteBlock complete = ^(QNResponseInfo *info, NSDictionary *resp, QNSessionStatistics *sessionStatistic) {
        
        [self reportRequestItemWithUpType:up_type_form info:info sessionStatistic:sessionStatistic fileOffset:0];
        
        if (info.isOK) {
            self.option.progressHandler(self.key, 1.0);
        }
        if (info.isOK || !info.couldRetry) {
            QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
            NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
            NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
            [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
            [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
            [Collector update:CK_fileSize value:@(self.data.length) identifier:self.identifier];
            [Collector resignWithIdentifier:self.identifier result:upload_ok];
            self.complete(info, self.key, resp);
            return;
        }
        if (self.option.cancellationSignal()) {
            QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
            NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
            NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
            [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
            [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
            [Collector update:CK_fileSize value:@(self.data.length) identifier:self.identifier];
            [Collector resignWithIdentifier:self.identifier result:user_canceled];
            self.complete([QNResponseInfo cancel], self.key, nil);
            return;
        }

        if (retried < self.config.retryMax) {
            [self nextTask:retried + 1 needDelay:YES host:host param:param];
        } else {
            if (self.config.allowBackupHost) {
                NSString *nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:host];
                if (nextHost) {
                    [self nextTask:0 needDelay:YES host:nextHost param:param];
                } else {
                    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                    if (self.currentZoneType == QNZoneInfoTypeMain && zonesInfo.hasBackupZone) {
                        self.currentZoneType = QNZoneInfoTypeBackup;
                        [self nextTask:0 needDelay:YES host:[self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil] param:param];
                    } else {
                        QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                        NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
                        NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
                        [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
                        [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
                        [Collector update:CK_fileSize value:@(self.data.length) identifier:self.identifier];
                        [Collector resignWithIdentifier:self.identifier result:sessionStatistic.errorType];
                        self.complete(info, self.key, resp);
                    }
                }
            } else {
                QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
                NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
                [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
                [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
                [Collector update:CK_fileSize value:@(self.data.length) identifier:self.identifier];
                [Collector resignWithIdentifier:self.identifier result:sessionStatistic.errorType];
                self.complete(info, self.key, resp);
            }
        }
    };
    [_sessionManager multipartPost:host
                       withData:_data
                     withParams:param
                   withFileName:_fileName
                   withMimeType:_option.mimeType
                    withIdentifier:_identifier
              withCompleteBlock:complete
              withProgressBlock:p
                withCancelBlock:_option.cancellationSignal
                     withAccess:_access];
}

- (void)reportRequestItemWithUpType:(NSString *)upType info:(QNResponseInfo *)info sessionStatistic:(QNSessionStatistics *)sessionStatistic fileOffset:(uint64_t)fileOffset {
    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
    NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
    NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
    
    QNReportRequestItem *item = [QNReportRequestItem buildWithUpType:upType
                                                        TargetBucket:self.token.bucket
                                                           targetKey:self.key
                                                          fileOffset:fileOffset
                                                      targetRegionId:targetRegionId
                                                     currentRegionId:currentRegionId
                                                   prefetchedIpCount:0
                                                                 pid:sessionStatistic.pid
                                                                 tid:sessionStatistic.tid
                                                          statusCode:info.statusCode
                                                               reqId:info.reqId
                                                                host:info.host
                                                            remoteIp:sessionStatistic.remoteIp
                                                                port:sessionStatistic.port totalElapsedTime:sessionStatistic.totalElapsedTime dnsElapsedTime:sessionStatistic.dnsElapsedTime connectElapsedTime:sessionStatistic.connectElapsedTime tlsConnectElapsedTime:sessionStatistic.tlsConnectElapsedTime requestElapsedTime:sessionStatistic.requestElapsedTime waitElapsedTime:sessionStatistic.waitElapsedTime responseElapsedTime:sessionStatistic.responseElapsedTime bytesSent:sessionStatistic.bytesSent bytesTotal:sessionStatistic.bytesTotal errorType:sessionStatistic.errorType errorDescription:sessionStatistic.errorDescription networkType:sessionStatistic.networkType signalStrength:sessionStatistic.signalStrength];
    [Collector append:CK_requestItem value:item identifier:self.identifier];
    if ([upType isEqualToString:up_type_mkblk] || [upType isEqualToString:up_type_bput]) {
        [Collector append:CK_blockBytesSent value:@(sessionStatistic.bytesSent) identifier:self.identifier];
    }
    [Collector append:CK_totalBytesSent value:@(sessionStatistic.bytesSent) identifier:self.identifier];
}
@end
