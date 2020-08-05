//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>

#if !TARGET_OS_MACCATALYST
#import <AssetsLibrary/AssetsLibrary.h>
#import "QNALAssetFile.h"
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#import "QNPHAssetFile.h"
#import <Photos/Photos.h>
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import "QNPHAssetResource.h"
#endif

#else
#import <CoreServices/CoreServices.h>
#endif

#import "QNAsyncRun.h"
#import "QNConfiguration.h"
#import "QNCrc32.h"
#import "QNFile.h"
#import "QNResponseInfo.h"

#import "QNFormUpload.h"
#import "QNResumeUpload.h"
#import "QNConcurrentResumeUpload.h"

#import "QNUpToken.h"
#import "QNUploadOption.h"
#import "QNReportItem.h"

#import "QNDnsPrefetch.h"
#import "QNZone.h"

@interface QNUploadManager ()
@property (nonatomic) QNConfiguration *config;
@end

@implementation QNUploadManager

- (instancetype)init {
    return [self initWithConfiguration:nil];
}

- (instancetype)initWithRecorder:(id<QNRecorderDelegate>)recorder {
    return [self initWithRecorder:recorder recorderKeyGenerator:nil];
}

- (instancetype)initWithRecorder:(id<QNRecorderDelegate>)recorder
            recorderKeyGenerator:(QNRecorderKeyGenerator)recorderKeyGenerator {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.recorder = recorder;
        builder.recorderKeyGen = recorderKeyGenerator;
    }];
    return [self initWithConfiguration:config];
}

- (instancetype)initWithConfiguration:(QNConfiguration *)config {
    if (self = [super init]) {
        if (config == nil) {
            config = [QNConfiguration build:^(QNConfigurationBuilder *builder){
            }];
        }
        _config = config;
        [[QNTransactionManager shared] addDnsLocalLoadTransaction];
    }
    return self;
}

+ (instancetype)sharedInstanceWithConfiguration:(QNConfiguration *)config {
    static QNUploadManager *sharedInstance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithConfiguration:config];
    });

    return sharedInstance;
}

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
    
    [self putData:data fileName:nil key:key token:token complete:completionHandler option:option];
}

- (void)putData:(NSData *)data
       fileName:(NSString *)fileName
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {

    if ([QNUploadManager checkAndNotifyError:key token:token input:data complete:completionHandler]) {
        return;
    }

    QNUpToken *t = [QNUpToken parse:token];
    if (t == nil) {
        QNResponseInfo *info = [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"];
        [QNUploadManager complete:token
                              key:key
                     responseInfo:info
                         response:nil
                      taskMetrics:nil
                         complete:completionHandler];
        return;
    }
    
    [[QNTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone token:t];
    
    QNUpTaskCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp) {
        [QNUploadManager complete:token
                              key:key
                     responseInfo:info
                         response:resp
                      taskMetrics:metrics
                         complete:completionHandler];
    };
    QNFormUpload *up = [[QNFormUpload alloc] initWithData:data
                                                      key:key
                                                 fileName:fileName
                                                    token:t
                                                   option:option
                                            configuration:self.config
                                        completionHandler:complete];
    QNAsyncRun(^{
        [up run];
    });
}

- (void)putFileInternal:(id<QNFileDelegate>)file
                    key:(NSString *)key
                  token:(NSString *)token
               complete:(QNUpCompletionHandler)completionHandler
                 option:(QNUploadOption *)option {
    
    @autoreleasepool {
        QNUpToken *t = [QNUpToken parse:token];
        if (t == nil) {
            QNResponseInfo *info = [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"];
            [QNUploadManager complete:token
                                  key:key
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }


        QNUpTaskCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp) {
            [file close];
            [QNUploadManager complete:token
                                  key:key
                         responseInfo:info
                             response:resp
                          taskMetrics:metrics
                             complete:completionHandler];
        };

        [[QNTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone token:t];

        if ([file size] <= self.config.putThreshold) {
            NSError *error;
            NSData *data = [file readAllWithError:&error];
            [file close];
            if (error) {
                QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
                [QNUploadManager complete:token
                                      key:key
                             responseInfo:info
                                 response:nil
                              taskMetrics:nil
                                 complete:completionHandler];
                return;
            }
            
            NSString *fileName = [[file path] lastPathComponent];
            [self putData:data
                 fileName:fileName
                      key:key
                    token:token
                 complete:completionHandler
                   option:option];
            return;
        }

        NSString *recorderKey = key;
        if (self.config.recorder != nil && self.config.recorderKeyGen != nil) {
            recorderKey = self.config.recorderKeyGen(key, [file path]);
        }
        
        if (self.config.useConcurrentResumeUpload) {
            QNConcurrentResumeUpload *up = [[QNConcurrentResumeUpload alloc]
                                            initWithFile:file
                                            key:key
                                            token:t
                                            option:option
                                            configuration:self.config
                                            recorder:self.config.recorder
                                            recorderKey:key
                                            completionHandler:complete];
            QNAsyncRun(^{
                [up run];
            });
        } else {
            QNResumeUpload *up = [[QNResumeUpload alloc]
                                  initWithFile:file
                                  key:key
                                  token:t
                                  option:option
                                  configuration:self.config
                                  recorder:self.config.recorder
                                  recorderKey:key
                                  completionHandler:complete];
            QNAsyncRun(^{
                [up run];
            });
        }
    }
}

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:filePath complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block QNFile *file = [[QNFile alloc] init:filePath error:&error];
        if (error) {
            QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
            [QNUploadManager complete:token
                                  key:key
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
}

#if !TARGET_OS_MACCATALYST
- (void)putALAsset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option {
#if __IPHONE_OS_VERSION_MIN_REQUIRED
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:asset complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block QNALAssetFile *file = [[QNALAssetFile alloc] init:asset error:&error];
        if (error) {
            QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
            [QNUploadManager complete:token
                                  key:key
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
#endif
}
#endif

- (void)putPHAsset:(PHAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90100)
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:asset complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block QNPHAssetFile *file = [[QNPHAssetFile alloc] init:asset error:&error];
        if (error) {
            QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
            [QNUploadManager complete:token
                                  key:key
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
#endif
}

- (void)putPHAssetResource:(PHAssetResource *)assetResource
                       key:(NSString *)key
                     token:(NSString *)token
                  complete:(QNUpCompletionHandler)completionHandler
                    option:(QNUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:assetResource complete:completionHandler]) {
        return;
    }
    @autoreleasepool {
        NSError *error = nil;
        __block QNPHAssetResource *file = [[QNPHAssetResource alloc] init:assetResource error:&error];
        if (error) {
            QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
            [QNUploadManager complete:token
                                  key:key
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }
        [self putFileInternal:file key:key token:token complete:completionHandler option:option];
    }
#endif
}

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                      input:(NSObject *)input
                   complete:(QNUpCompletionHandler)completionHandler {
    if (completionHandler == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"no completionHandler"
                                     userInfo:nil];
        return YES;
    }
    
    QNResponseInfo *info = nil;
    if (input == nil) {
        info = [QNResponseInfo responseInfoOfZeroData:@"no input data"];
    } else if ([input isKindOfClass:[NSData class]] && [(NSData *)input length] == 0) {
        info = [QNResponseInfo responseInfoOfZeroData:@"no input data"];
    } else if (token == nil || [token isEqual:[NSNull null]] || [token isEqualToString:@""]) {
        info = [QNResponseInfo responseInfoWithInvalidToken:@"no token"];
    }
    if (info != nil) {
        [QNUploadManager complete:token
                              key:key
                     responseInfo:info
                         response:nil
                      taskMetrics:nil
                         complete:completionHandler];
        return YES;
    } else {
        return NO;
    }
}

+ (void)complete:(NSString *)token
             key:(NSString *)key
    responseInfo:(QNResponseInfo *)responseInfo
        response:(NSDictionary *)response
     taskMetrics:(QNUploadTaskMetrics *)taskMetrics
        complete:(QNUpCompletionHandler)completionHandler {

    [QNUploadManager reportQuality:responseInfo taskMetrics:taskMetrics token:token];
    
    QNAsyncRunInMain(^{
        if (completionHandler) {
            completionHandler(responseInfo, key, response);
        }
    });
}


//MARK:-- 统计quality日志
+ (void)reportQuality:(QNResponseInfo *)info
          taskMetrics:(QNUploadTaskMetrics *)taskMetrics
                token:(NSString *)token{
    
    QNUploadTaskMetrics *taskMetricsP = taskMetrics ?: [QNUploadTaskMetrics emptyMetrics];
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeQuality forKey:QNReportQualityKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportQualityKeyUpTime];
    [item setReportValue:info.qualityResult forKey:QNReportQualityKeyResult];
    [item setReportValue:taskMetricsP.totalElapsedTime forKey:QNReportQualityKeyTotalElapsedTime];
    [item setReportValue:taskMetricsP.requestCount forKey:QNReportQualityKeyRequestsCount];
    [item setReportValue:taskMetricsP.regionCount forKey:QNReportQualityKeyRegionsCount];
    [item setReportValue:taskMetricsP.bytesSend forKey:QNReportQualityKeyBytesSent];
    [kQNReporter reportItem:item token:token];
}

@end
