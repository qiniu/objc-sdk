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
#import "QNUploadInfoReporter.h"

@interface QNFormUpload ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) id<QNHttpDelegate> httpManager;
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
@property (nonatomic, copy) NSString *taskIdentifier;

@end

@implementation QNFormUpload

- (instancetype)initWithData:(NSData *)data
                     withKey:(NSString *)key
                withFileName:(NSString *)fileName
                   withToken:(QNUpToken *)token
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
             withHttpManager:(id<QNHttpDelegate>)http
           withConfiguration:(QNConfiguration *)config {
    if (self = [super init]) {
        _data = data;
        _key = key;
        _token = token;
        _option = option != nil ? option : [QNUploadOption defaultOptions];
        _complete = block;
        _httpManager = http;
        _config = config;
        _fileName = fileName != nil ? fileName : @"?";
        _previousPercent = 0;
        _access = token.access;
        _currentZoneType = QNZoneInfoTypeMain;
        _taskIdentifier = [[NSUUID UUID] UUIDString];
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
    QNCompleteBlock complete = ^(QNResponseInfo *info, NSDictionary *resp) {
        [UploadInfoReporter recordWithRequestType:ReportType_form
                                     responseInfo:info
                                        bytesSent:(UInt32)self.data.length
                                         fileSize:(UInt32)self.data.length
                                            token:self.token.token];
        if (info.isOK) {
            self.option.progressHandler(self.key, 1.0);
        }
        if (info.isOK || !info.couldRetry) {
            self.complete(info, self.key, resp);
            return;
        }
        if (self.option.cancellationSignal()) {
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
                        self.complete(info, self.key, resp);
                    }
                }
            } else {
                self.complete(info, self.key, resp);
            }
        }
    };
    [_httpManager multipartPost:host
                       withData:_data
                     withParams:param
                   withFileName:_fileName
                   withMimeType:_option.mimeType
             withTaskIdentifier:_taskIdentifier
              withCompleteBlock:complete
              withProgressBlock:p
                withCancelBlock:_option.cancellationSignal
                     withAccess:_access];
}
@end
