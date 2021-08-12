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
#import "QNUtils.h"
#import "QNResponseInfo.h"

#import "QNFormUpload.h"
#import "QNPartsUpload.h"
#import "QNConcurrentResumeUpload.h"

#import "QNUpToken.h"
#import "QNUploadOption.h"
#import "QNReportItem.h"

#import "QNDnsPrefetch.h"
#import "QNZone.h"

#import "QNUploadSourceFile.h"
#import "QNUploadSourceStream.h"

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
    if (t == nil || ![t isValid]) {
        QNResponseInfo *info = [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"];
        [QNUploadManager complete:token
                              key:key
                           source:data
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
                           source:data
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

- (void)putInputStream:(NSInputStream *)inputStream
              sourceId:(NSString *)sourceId
                  size:(long long)size
              fileName:(NSString *)fileName
                   key:(NSString *)key
                 token:(NSString *)token
              complete:(QNUpCompletionHandler)completionHandler
                option:(QNUploadOption *)option {
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:inputStream complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        QNUploadSourceStream *source = [QNUploadSourceStream stream:inputStream sourceId:sourceId size:size fileName:fileName];
        [self putInternal:source key:key token:token complete:completionHandler option:option];
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
                               source:nil
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
                               source:nil
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
                               source:nil
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
                               source:nil
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

- (void)putFileInternal:(id<QNFileDelegate>)file
                    key:(NSString *)key
                  token:(NSString *)token
               complete:(QNUpCompletionHandler)completionHandler
                 option:(QNUploadOption *)option {
    [self putInternal:[QNUploadSourceFile file:file]
                  key:key token:token
             complete:completionHandler
               option:option];
}

- (void)putInternal:(id<QNUploadSource>)source
                key:(NSString *)key
              token:(NSString *)token
           complete:(QNUpCompletionHandler)completionHandler
             option:(QNUploadOption *)option {
    
    @autoreleasepool {
        QNUpToken *t = [QNUpToken parse:token];
        if (t == nil || ![t isValid]) {
            QNResponseInfo *info = [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"];
            [QNUploadManager complete:token
                                  key:key
                               source:source
                         responseInfo:info
                             response:nil
                          taskMetrics:nil
                             complete:completionHandler];
            return;
        }


        QNUpTaskCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp) {
            [QNUploadManager complete:token
                                  key:key
                               source:source
                         responseInfo:info
                             response:resp
                          taskMetrics:metrics
                             complete:completionHandler];
        };

        [[QNTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone token:t];

        long long sourceSize = [source getSize];
        if (sourceSize > 0 && sourceSize <= self.config.putThreshold) {
            NSError *error;
            NSData *data = [source readData:sourceSize dataOffset:0 error:&error];
            [source close];
            if (error) {
                QNResponseInfo *info = [QNResponseInfo responseInfoWithFileError:error];
                [QNUploadManager complete:token
                                      key:key
                                   source:source
                             responseInfo:info
                                 response:nil
                              taskMetrics:nil
                                 complete:completionHandler];
                return;
            }
            
            [self putData:data
                 fileName:[source getFileName]
                      key:key
                    token:token
                 complete:completionHandler
                   option:option];
            return;
        }

        NSString *recorderKey = key;
        if (self.config.recorder != nil && self.config.recorderKeyGen != nil) {
            recorderKey = self.config.recorderKeyGen(key, [source getId]);
        }
        
        if (self.config.useConcurrentResumeUpload) {
            QNConcurrentResumeUpload *up = [[QNConcurrentResumeUpload alloc]
                                            initWithSource:source
                                            key:key
                                            token:t
                                            option:option
                                            configuration:self.config
                                            recorder:self.config.recorder
                                            recorderKey:recorderKey
                                            completionHandler:complete];
            QNAsyncRun(^{
                [up run];
            });
        } else {
            QNPartsUpload *up = [[QNPartsUpload alloc]
                                 initWithSource:source
                                 key:key
                                 token:t
                                 option:option
                                 configuration:self.config
                                 recorder:self.config.recorder
                                 recorderKey:recorderKey
                                 completionHandler:complete];
            QNAsyncRun(^{
                [up run];
            });
        }
    }
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
                           source:nil
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
          source:(NSObject *)source
    responseInfo:(QNResponseInfo *)responseInfo
        response:(NSDictionary *)response
     taskMetrics:(QNUploadTaskMetrics *)taskMetrics
        complete:(QNUpCompletionHandler)completionHandler {
    
    [QNUploadManager reportQuality:key source:source responseInfo:responseInfo taskMetrics:taskMetrics token:token];
    
    QNAsyncRunInMain(^{
        if (completionHandler) {
            completionHandler(responseInfo, key, response);
        }
    });
}


//MARK:-- 统计quality日志
+ (void)reportQuality:(NSString *)key
               source:(NSObject *)source
         responseInfo:(QNResponseInfo *)responseInfo
          taskMetrics:(QNUploadTaskMetrics *)taskMetrics
                token:(NSString *)token{
    
    QNUpToken *upToken = [QNUpToken parse:token];
    QNUploadTaskMetrics *taskMetricsP = taskMetrics ?: [QNUploadTaskMetrics emptyMetrics];
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeQuality forKey:QNReportQualityKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportQualityKeyUpTime];
    [item setReportValue:responseInfo.qualityResult forKey:QNReportQualityKeyResult];
    [item setReportValue:upToken.bucket forKey:QNReportQualityKeyTargetBucket];
    [item setReportValue:key forKey:QNReportQualityKeyTargetKey];
    [item setReportValue:taskMetricsP.totalElapsedTime forKey:QNReportQualityKeyTotalElapsedTime];
    [item setReportValue:taskMetricsP.totalElapsedTime forKey:QNReportQualityKeyTotalElapsedTime];
    [item setReportValue:taskMetricsP.requestCount forKey:QNReportQualityKeyRequestsCount];
    [item setReportValue:taskMetricsP.regionCount forKey:QNReportQualityKeyRegionsCount];
    [item setReportValue:taskMetricsP.bytesSend forKey:QNReportQualityKeyBytesSent];
    
    [item setReportValue:[QNUtils systemName] forKey:QNReportQualityKeyOsName];
    [item setReportValue:[QNUtils systemVersion] forKey:QNReportQualityKeyOsVersion];
    [item setReportValue:[QNUtils sdkLanguage] forKey:QNReportQualityKeySDKName];
    [item setReportValue:[QNUtils sdkVersion] forKey:QNReportQualityKeySDKVersion];
    
    [item setReportValue:responseInfo.requestReportErrorType forKey:QNReportQualityKeyErrorType];
    NSString *errorDesc = responseInfo.requestReportErrorType ? responseInfo.message : nil;
    [item setReportValue:errorDesc forKey:QNReportQualityKeyErrorDescription];
    
    long long fileSize = -1;
    if ([source conformsToProtocol:@protocol(QNUploadSource)]) {
        fileSize = [(id <QNUploadSource>)source getSize];
    } else if ([source isKindOfClass:[NSData class]]) {
        fileSize = [(NSData *)source length];
    }
    [item setReportValue:@(fileSize) forKey:QNReportQualityKeyFileSize];
    if (responseInfo.isOK && fileSize > 0 && taskMetrics.totalElapsedTime) {
        NSNumber *speed = [QNUtils calculateSpeed:fileSize totalTime:taskMetrics.totalElapsedTime.longLongValue];
        [item setReportValue:speed forKey:QNReportQualityKeyPerceptiveSpeed];
    }
    
    [kQNReporter reportItem:item token:token];
}

@end
