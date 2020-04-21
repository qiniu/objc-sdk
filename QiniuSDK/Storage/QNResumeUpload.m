//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"

@interface QNResumeUpload ()

@property (nonatomic, copy) NSString *recorderKey;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSMutableArray *contexts;

@property (nonatomic, strong) id<QNRecorderDelegate> recorder;
@property (nonatomic, strong) id<QNFileDelegate> file;
@property (nonatomic, copy) NSString *recordHost; // upload host in last recorder file

@property (nonatomic, assign) UInt32 chunkCrc;
@property (nonatomic, assign) float previousPercent;
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
        self.file = file;
        self.size = (UInt32)[file size];
        self.key = key;
        NSString *tokenUp = [NSString stringWithFormat:@"UpToken %@", token.token];
        self.option = option != nil ? option : [QNUploadOption defaultOptions];
        self.complete = block;
        self.headers = @{@"Authorization" : tokenUp, @"Content-Type" : @"application/octet-stream"};
        self.recorder = recorder;
        self.sessionManager = sessionManager;
        self.modifyTime = [file modifyTime];
        self.recorderKey = recorderKey;
        self.contexts = [[NSMutableArray alloc] initWithCapacity:(self.size + kQNBlockSize - 1) / kQNBlockSize];
        self.config = config;
        self.currentZoneType = QNZoneInfoTypeMain;
        self.token = token;
        self.previousPercent = 0;
        self.access = token.access;
        self.identifier = identifier;
        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
    }
    return self;
}

- (void)record:(UInt32)offset host:(NSString *)host {
    NSString *key = self.recorderKey;
    if (offset == 0 || self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }
    NSNumber *n_size = @(self.size);
    NSNumber *n_offset = @(offset);
    NSNumber *n_time = [NSNumber numberWithLongLong:self.modifyTime];
    NSMutableDictionary *rec = [NSMutableDictionary dictionaryWithObjectsAndKeys:n_size, @"size", n_offset, @"offset", n_time, @"modify_time", host, @"host", self.contexts, @"contexts", nil];

    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:rec options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"up record json error %@ %@", key, error);
        return;
    }
    error = [self.recorder set:key data:data];
    if (error != nil) {
        NSLog(@"up record set error %@ %@", key, error);
    }
}

- (void)removeRecord {
    if (self.recorder == nil) {
        return;
    }
    self.recordHost = nil;
    [self.contexts removeAllObjects];
    [self.recorder del:self.recorderKey];
}

- (UInt32)recoveryFromRecord {
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return 0;
    }

    NSData *data = [self.recorder get:key];
    if (data == nil) {
        return 0;
    }

    NSError *error;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil) {
        NSLog(@"recovery error %@ %@", key, error);
        [self.recorder del:self.key];
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
    if (t != self.modifyTime) {
        NSLog(@"modify time changed %llu, %llu", t, self.modifyTime);
        return 0;
    }
    self.recordHost = info[@"host"];
    self.contexts = [[NSMutableArray alloc] initWithArray:contexts copyItems:true];
    return offset;
}

- (void)nextTask:(UInt32)offset needDelay:(BOOL)needDelay retriedTimes:(int)retried host:(NSString *)host {
    if (needDelay) {
        QNAsyncRunAfter(self.config.retryInterval, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self nextTask:offset retriedTimes:retried host:host];
        });
    } else {
        [self nextTask:offset retriedTimes:retried host:host];
    }
}

- (void)nextTask:(UInt32)offset retriedTimes:(int)retried host:(NSString *)host {

    if (self.option.cancellationSignal()) {
        [self collectUploadQualityInfo];
        QNResponseInfo *info = [Collector userCancel:self.identifier];
        self.complete(info, self.key, nil);
        return;
    }

    if (offset == self.size) {
        QNCompleteBlock completionHandler = ^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
            
            [self collectHttpResponseInfo:httpResponseInfo fileOffset:offset];
            
            if (httpResponseInfo.isOK) {
                [self removeRecord];
                self.option.progressHandler(self.key, 1.0);
                [self collectUploadQualityInfo];
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                self.complete(info, self.key, respBody);
            } else if (httpResponseInfo.couldRetry) {
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
                                [self collectUploadQualityInfo];
                                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                                self.complete(info, self.key, respBody);
                            }
                        }
                    } else {
                        [self collectUploadQualityInfo];
                        QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                        self.complete(info, self.key, respBody);
                    }
                }
            } else {
                [self collectUploadQualityInfo];
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                self.complete(info, self.key, respBody);
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

    QNCompleteBlock completionHandler = ^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        
        [self collectHttpResponseInfo:httpResponseInfo fileOffset:offset];
        
        if (httpResponseInfo.error != nil) {
            if (httpResponseInfo.couldRetry) {
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
                                [self collectUploadQualityInfo];
                                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                                self.complete(info, self.key, respBody);
                            }
                        }
                    } else {
                        [self collectUploadQualityInfo];
                        QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                        self.complete(info, self.key, respBody);
                    }
                }
            } else {
                if (httpResponseInfo.statusCode == 701) {
                    [self nextTask:(offset / kQNBlockSize) * kQNBlockSize needDelay:YES retriedTimes:0 host:host];
                } else {
                    [self collectUploadQualityInfo];
                    QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                    self.complete(info, self.key, respBody);
                }
            }
            return;
        }

        NSDictionary *resp = [httpResponseInfo getResponseBody];
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
    NSString *context = self.contexts[offset / kQNBlockSize];
    [self putChunk:host offset:offset size:chunkSize context:context progress:progressBlock complete:completionHandler];
}

- (UInt32)calcPutSize:(UInt32)offset {
    UInt32 left = self.size - offset;
    return left < self.config.chunkSize ? left : self.config.chunkSize;
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
    self.requestType = QNRequestType_mkblk;
    NSError *error;
    NSData *data = [self.file read:offset size:chunkSize error:&error];
    if (error) {
        [self collectUploadQualityInfo];
        QNResponseInfo *info = [Collector completeWithFileError:error identifier:self.identifier];
        self.complete(info, self.key, nil);
        return;
    }
    NSString *url = [[NSString alloc] initWithFormat:@"%@/mkblk/%u", uphost, (unsigned int)blockSize];
    self.chunkCrc = [QNCrc32 data:data];
    [self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
    self.requestType = QNRequestType_bput;
    NSError *error;
    NSData *data = [self.file read:offset size:size error:&error];
    if (error) {
        [self collectUploadQualityInfo];
        QNResponseInfo *info = [Collector completeWithFileError:error identifier:self.identifier];
        self.complete(info, self.key, nil);
        return;
    }
    UInt32 chunkOffset = offset % kQNBlockSize;
    NSString *url = [[NSString alloc] initWithFormat:@"%@/bput/%@/%u", uphost, context, (unsigned int)chunkOffset];
    self.chunkCrc = [QNCrc32 data:data];
    [self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete {

    self.requestType = QNRequestType_mkfile;
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
    return [[self.file path] lastPathComponent];
}

- (void)post:(NSString *)url
             withData:(NSData *)data
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock {
    [self.sessionManager post:url withData:data withParams:nil withHeaders:self.headers withIdentifier:self.identifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:self.option.cancellationSignal withAccess:self.access];
}

- (void)run {
    @autoreleasepool {
        UInt32 offset = [self recoveryFromRecord];
        [Collector update:CK_recoveredFrom value:@(offset) identifier:self.identifier];
        
        if (offset > 0) {
            [self nextTask:offset needDelay:NO retriedTimes:0 host:self.recordHost];
        } else {
            [self nextTask:offset needDelay:NO retriedTimes:0 host:[self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil]];
        }
    }
}

@end
