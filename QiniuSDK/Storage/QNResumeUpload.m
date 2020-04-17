//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNConfiguration.h"
#import "QNCrc32.h"
#import "QNRecorderDelegate.h"
#import "QNResponseInfo.h"
#import "QNUploadManager.h"
#import "QNUploadOption+Private.h"
#import "QNUrlSafeBase64.h"
#import "QNAsyncRun.h"
#import "QNUploadInfoCollector.h"

@interface QNResumeUpload ()

@property (nonatomic, strong) QNSessionManager *sessionManager;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *recorderKey;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, copy) NSString *access; //AK
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic, strong) QNUpCompletionHandler complete;
@property (nonatomic, strong) NSMutableArray *contexts;
@property (nonatomic, assign) QNZoneInfoType currentZoneType;
@property (nonatomic, copy) NSString *upType;

@property (nonatomic, strong) id<QNRecorderDelegate> recorder;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id<QNFileDelegate> file;
@property (nonatomic, copy) NSString *recordHost; // upload host in last recorder file
@property (nonatomic, copy) NSString *identifier;

@property (nonatomic, assign) UInt32 chunkCrc;
@property (nonatomic, assign) float previousPercent;
@property (nonatomic, assign) UInt32 size;
@property (nonatomic, assign) int64_t modifyTime;

@end

@implementation QNResumeUpload

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                     withKey:(NSString *)key
                   withToken:(QNUpToken *)token
              withIdentifier:(NSString *)identifier
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
                withRecorder:(id<QNRecorderDelegate>)recorder
             withRecorderKey:(NSString *)recorderKey
             withSessionManager:(QNSessionManager *)sessionManager
           withConfiguration:(QNConfiguration *)config;
{
    if (self = [super init]) {
        _file = file;
        _size = (UInt32)[file size];
        _key = key;
        NSString *tokenUp = [NSString stringWithFormat:@"UpToken %@", token.token];
        _option = option != nil ? option : [QNUploadOption defaultOptions];
        _complete = block;
        _headers = @{@"Authorization" : tokenUp, @"Content-Type" : @"application/octet-stream"};
        _recorder = recorder;
        _sessionManager = sessionManager;
        _modifyTime = [file modifyTime];
        _recorderKey = recorderKey;
        _contexts = [[NSMutableArray alloc] initWithCapacity:(_size + kQNBlockSize - 1) / kQNBlockSize];
        _config = config;
        _currentZoneType = QNZoneInfoTypeMain;
        _token = token;
        _previousPercent = 0;
        _access = token.access;
        _identifier = identifier;
    }
    return self;
}

- (void)record:(UInt32)offset host:(NSString *)host {
    NSString *key = self.recorderKey;
    if (offset == 0 || _recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }
    NSNumber *n_size = @(self.size);
    NSNumber *n_offset = @(offset);
    NSNumber *n_time = [NSNumber numberWithLongLong:_modifyTime];
    NSMutableDictionary *rec = [NSMutableDictionary dictionaryWithObjectsAndKeys:n_size, @"size", n_offset, @"offset", n_time, @"modify_time", host, @"host", _contexts, @"contexts", nil];

    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:rec options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"up record json error %@ %@", key, error);
        return;
    }
    error = [_recorder set:key data:data];
    if (error != nil) {
        NSLog(@"up record set error %@ %@", key, error);
    }
}

- (void)removeRecord {
    if (_recorder == nil) {
        return;
    }
    _recordHost = nil;
    [_contexts removeAllObjects];
    [_recorder del:self.recorderKey];
}

- (UInt32)recoveryFromRecord {
    NSString *key = self.recorderKey;
    if (_recorder == nil || key == nil || [key isEqualToString:@""]) {
        return 0;
    }

    NSData *data = [_recorder get:key];
    if (data == nil) {
        return 0;
    }

    NSError *error;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil) {
        NSLog(@"recovery error %@ %@", key, error);
        [_recorder del:self.key];
        return 0;
    }
    NSNumber *n_offset = info[@"offset"];
    NSNumber *n_size = info[@"size"];
    NSNumber *time = info[@"modify_time"];
    NSArray *contexts = info[@"contexts"];
    if (n_offset == nil || n_size == nil || time == nil || contexts == nil) {
        return 0;
    }
    
    UInt32 offset = [n_offset unsignedIntValue];
    UInt32 size = [n_size unsignedIntValue];
    if (offset > size || size != self.size) {
        return 0;
    }
    UInt64 t = [time unsignedLongLongValue];
    if (t != _modifyTime) {
        NSLog(@"modify time changed %llu, %llu", t, _modifyTime);
        return 0;
    }
    _recordHost = info[@"host"];
    _contexts = [[NSMutableArray alloc] initWithArray:contexts copyItems:true];
    return offset;
}

- (void)nextTask:(UInt32)offset needDelay:(BOOL)needDelay retriedTimes:(int)retried host:(NSString *)host {
    if (needDelay) {
        QNAsyncRunAfter(_config.retryInterval, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self nextTask:offset retriedTimes:retried host:host];
        });
    } else {
        [self nextTask:offset retriedTimes:retried host:host];
    }
}

- (void)nextTask:(UInt32)offset retriedTimes:(int)retried host:(NSString *)host {

    if (self.option.cancellationSignal()) {
        QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
        NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
        NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
        [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
        [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
        [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
        [Collector resignWithIdentifier:self.identifier result:user_canceled];
        self.complete([QNResponseInfo cancel], self.key, nil);
        return;
    }

    if (offset == self.size) {
        QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp, QNSessionStatistics *sessionStatistic) {
            
            [self reportRequestItemWithUpType:self.upType info:info sessionStatistic:sessionStatistic fileOffset:offset];
            
            if (info.isOK) {
                [self removeRecord];
                self.option.progressHandler(self.key, 1.0);
                QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
                NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
                [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
                [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
                [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                [Collector resignWithIdentifier:self.identifier result:upload_ok];
                self.complete(info, self.key, resp);
            } else if (info.couldRetry) {
                if (retried < self.config.retryMax) {
                    [self nextTask:offset needDelay:YES retriedTimes:retried + 1 host:host];
                } else {
                    if (self.config.allowBackupHost) {
                        NSString *nextHost = nil;
                        UInt32 nextOffset = 0;
                        if (self.recordHost) {
                            self.previousPercent = 0;
                            [self removeRecord];
                            self.currentZoneType = QNZoneInfoTypeMain;
                            nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil];
                            nextOffset = 0;
                        } else {
                            nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:host];
                            nextOffset = offset;
                        }
                        
                        if (nextHost) {
                            [self nextTask:nextOffset needDelay:YES retriedTimes:0 host:nextHost];
                        } else {
                            QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                            if (self.currentZoneType == QNZoneInfoTypeMain && zonesInfo.hasBackupZone) {
                                self.currentZoneType = QNZoneInfoTypeBackup;
                                self.previousPercent = 0;
                                [self removeRecord];
                                [self nextTask:0 needDelay:YES retriedTimes:0 host:[self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil]];
                            } else {
                                QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                                NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
                                NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
                                [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
                                [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
                                [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                                [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                                [Collector resignWithIdentifier:self.identifier result:upload_ok];
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
                        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                        [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                        [Collector resignWithIdentifier:self.identifier result:upload_ok];
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
                [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                [Collector resignWithIdentifier:self.identifier result:upload_ok];
                [Collector resignWithIdentifier:self.identifier result:sessionStatistic.errorType];
                self.complete(info, self.key, resp);
            }
        };
        [self makeFile:host complete:completionHandler];
        return;
    }

    UInt32 chunkSize = [self calcPutSize:offset];
    QNInternalProgressBlock progressBlock = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        float percent = (float)(offset + totalBytesWritten) / (float)self.size;
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

    QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp, QNSessionStatistics *sessionStatistic) {
        
        [self reportRequestItemWithUpType:self.upType info:info sessionStatistic:sessionStatistic fileOffset:offset];
        
        if (info.error != nil) {
            if (info.couldRetry) {
                if (retried < self.config.retryMax) {
                    [self nextTask:offset needDelay:YES retriedTimes:retried + 1 host:host];
                } else {
                    if (self.config.allowBackupHost) {
                        NSString *nextHost = nil;
                        UInt32 nextOffset = 0;
                        if (self.recordHost) {
                            self.previousPercent = 0;
                            [self removeRecord];
                            self.currentZoneType = QNZoneInfoTypeMain;
                            nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil];
                            nextOffset = 0;
                        } else {
                            nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:host];
                            nextOffset = offset;
                        }

                        if (nextHost) {
                            [self nextTask:nextOffset needDelay:YES retriedTimes:0 host:nextHost];
                        } else {
                            QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                            if (self.currentZoneType == QNZoneInfoTypeMain && zonesInfo.hasBackupZone) {
                                self.currentZoneType = QNZoneInfoTypeBackup;
                                self.previousPercent = 0;
                                [self removeRecord];
                                [self nextTask:0 needDelay:YES retriedTimes:0 host:[self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil]];
                            } else {
                                QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                                NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
                                NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
                                [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
                                [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
                                [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                                [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                                [Collector resignWithIdentifier:self.identifier result:upload_ok];
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
                        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                        [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                        [Collector resignWithIdentifier:self.identifier result:upload_ok];
                        [Collector resignWithIdentifier:self.identifier result:sessionStatistic.errorType];
                        self.complete(info, self.key, resp);
                    }
                }
            } else {
                if (info.statusCode == 701) {
                    [self nextTask:(offset / kQNBlockSize) * kQNBlockSize needDelay:YES retriedTimes:0 host:host];
                } else {
                    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                    NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
                    NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
                    [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
                    [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
                    [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
                    [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
                    [Collector resignWithIdentifier:self.identifier result:upload_ok];
                    [Collector resignWithIdentifier:self.identifier result:sessionStatistic.errorType];
                    self.complete(info, self.key, resp);
                }
            }
            return;
        }

        if (resp == nil) {
            [self nextTask:offset needDelay:YES retriedTimes:retried host:host];
            return;
        }

        NSString *ctx = resp[@"ctx"];
        NSNumber *crc = resp[@"crc32"];
        if (ctx == nil || crc == nil || [crc unsignedLongValue] != self.chunkCrc) {
            [self nextTask:offset needDelay:YES retriedTimes:retried host:host];
            return;
        }
        self.contexts[offset / kQNBlockSize] = ctx;
        [self record:offset + chunkSize host:host];
        [self nextTask:offset + chunkSize needDelay:NO retriedTimes:retried host:host];
    };
    if (offset % kQNBlockSize == 0) {
        UInt32 blockSize = [self calcBlockSize:offset];
        [self makeBlock:host offset:offset blockSize:blockSize chunkSize:chunkSize progress:progressBlock complete:completionHandler];
        return;
    }
    NSString *context = _contexts[offset / kQNBlockSize];
    [self putChunk:host offset:offset size:chunkSize context:context progress:progressBlock complete:completionHandler];
}

- (UInt32)calcPutSize:(UInt32)offset {
    UInt32 left = self.size - offset;
    return left < _config.chunkSize ? left : _config.chunkSize;
}

- (UInt32)calcBlockSize:(UInt32)offset {
    UInt32 left = self.size - offset;
    return left < kQNBlockSize ? left : kQNBlockSize;
}

- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
        blockSize:(UInt32)blockSize
        chunkSize:(UInt32)chunkSize
         progress:(QNInternalProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete {
    _upType = up_type_mkblk;
    NSError *error;
    NSData *data = [self.file read:offset size:chunkSize error:&error];
    if (error) {
        QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
        NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
        NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
        [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
        [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
        [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
        [Collector resignWithIdentifier:self.identifier result:upload_ok];
        [Collector resignWithIdentifier:self.identifier result:invalid_file];
        self.complete([QNResponseInfo responseInfoWithFileError:error], self.key, nil);
        return;
    }
    NSString *url = [[NSString alloc] initWithFormat:@"%@/mkblk/%u", uphost, (unsigned int)blockSize];
    _chunkCrc = [QNCrc32 data:data];
    [self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
    _upType = up_type_bput;
    NSError *error;
    NSData *data = [self.file read:offset size:size error:&error];
    if (error) {
        QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
        NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
        NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
        [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
        [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
        [Collector update:CK_fileSize value:@(self.file.size) identifier:self.identifier];
        [Collector resignWithIdentifier:self.identifier result:upload_ok];
        [Collector resignWithIdentifier:self.identifier result:invalid_file];
        self.complete([QNResponseInfo responseInfoWithFileError:error], self.key, nil);
        return;
    }
    UInt32 chunkOffset = offset % kQNBlockSize;
    NSString *url = [[NSString alloc] initWithFormat:@"%@/bput/%@/%u", uphost, context, (unsigned int)chunkOffset];
    _chunkCrc = [QNCrc32 data:data];
    [self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete {

    _upType = up_type_mkfile;
    NSString *mime = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.option.mimeType]];

    __block NSString *url = [[NSString alloc] initWithFormat:@"%@/mkfile/%u%@", uphost, (unsigned int)self.size, mime];

    if (self.key != nil) {
        NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNUrlSafeBase64 encodeString:self.key]];
        url = [NSString stringWithFormat:@"%@%@", url, keyStr];
    }

    [self.option.params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        url = [NSString stringWithFormat:@"%@/%@/%@", url, key, [QNUrlSafeBase64 encodeString:obj]];
    }];

    //添加路径
    NSString *fname = [[NSString alloc] initWithFormat:@"/fname/%@", [QNUrlSafeBase64 encodeString:[self fileBaseName]]];
    url = [NSString stringWithFormat:@"%@%@", url, fname];

    NSMutableData *postData = [NSMutableData data];
    NSString *bodyStr = [self.contexts componentsJoinedByString:@","];
    [postData appendData:[bodyStr dataUsingEncoding:NSUTF8StringEncoding]];
    [self post:url withData:postData withCompleteBlock:complete withProgressBlock:nil];
}

#pragma mark - 处理文件路径
- (NSString *)fileBaseName {
    return [[_file path] lastPathComponent];
}

- (void)post:(NSString *)url
             withData:(NSData *)data
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock {
    [_sessionManager post:url withData:data withParams:nil withHeaders:_headers withIdentifier:_identifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:_option.cancellationSignal withAccess:_access];
}

- (void)run {
    @autoreleasepool {
        UInt32 offset = [self recoveryFromRecord];
        [Collector update:CK_recoveredFrom value:@(offset) identifier:self.identifier];
        
        if (offset > 0) {
            [self nextTask:offset needDelay:NO retriedTimes:0 host:_recordHost];
        } else {
            [self nextTask:offset needDelay:NO retriedTimes:0 host:[_config.zone up:_token zoneInfoType:_currentZoneType isHttps:_config.useHttps frozenDomain:nil]];
        }
    }
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
