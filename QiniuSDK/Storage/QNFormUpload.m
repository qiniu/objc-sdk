//
//  QNFormUpload.m
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNFormUpload.h"

@interface QNFormUpload ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic) int retryTimes;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic) float previousPercent;

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
        self.data = data;
        self.size = (UInt32)data.length;
        self.key = key;
        self.token = token;
        self.option = option != nil ? option : [QNUploadOption defaultOptions];
        self.complete = block;
        self.sessionManager = sessionManager;
        self.config = config;
        self.fileName = fileName != nil ? fileName : @"?";
        self.previousPercent = 0;
        self.access = token.access;
        self.currentZoneType = QNZoneInfoTypeMain;
        self.identifier = identifier;
        self.requestType = QNRequestType_form;
    }
    return self;
}

- (void)put {
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (self.key) {
        parameters[@"key"] = self.key;
    }
    parameters[@"token"] = self.token.token;
    [parameters addEntriesFromDictionary:self.option.params];
    parameters[@"crc32"] = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:_data]];
    
    [self nextTask:0 needDelay:NO host:[self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil] param:parameters];
}

- (void)nextTask:(int)retried needDelay:(BOOL)needDelay host:(NSString *)host param:(NSDictionary *)param {
    
    if (needDelay) {
        QNAsyncRunAfter(self.config.retryInterval, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self nextTask:retried host:host param:param];
        });
    } else {
        [self nextTask:retried host:host param:param];
    }
}

- (void)nextTask:(int)retried host:(NSString *)host param:(NSDictionary *)param {
        
    if (self.option.cancellationSignal()) {
        [self collectUploadQualityInfo];
        QNResponseInfo *info = [Collector userCancel:self.identifier];
        self.complete(info, self.key, nil);
        return;
    }
        
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
    QNCompleteBlock complete = ^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        [self collectHttpResponseInfo:httpResponseInfo fileOffset:0];
        
        if (httpResponseInfo.isOK) {
            self.option.progressHandler(self.key, 1.0);
            [self collectUploadQualityInfo];
            QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
            self.complete(info, self.key, respBody);
        } else if (httpResponseInfo.couldRetry) {
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
    [self.sessionManager multipartPost:host
                              withData:self.data
                     withParams:param
                          withFileName:self.fileName
                          withMimeType:self.option.mimeType
                        withIdentifier:self.identifier
              withCompleteBlock:complete
              withProgressBlock:p
                       withCancelBlock:self.option.cancellationSignal
                            withAccess:self.access];
}

@end
