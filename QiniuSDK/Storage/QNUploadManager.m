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
#import "QNFormUpload.h"
#import "QNResponseInfo.h"
#import "QNResumeUpload.h"
#import "QNSessionManager.h"
#import "QNUpToken.h"
#import "QNUploadManager.h"
#import "QNUploadOption+Private.h"
#import "QNConcurrentResumeUpload.h"
#import "QNUploadInfoCollector.h"

#import "QNDnsPrefetcher.h"
#import "QNZone.h"

@interface QNUploadManager ()
@property (nonatomic) QNSessionManager *sessionManager;
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
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
        _sessionManager = [[QNSessionManager alloc] initWithProxy:config.proxy timeout:config.timeoutInterval urlConverter:config.converter];
#endif
        
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

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                      input:(NSObject *)input
                 identifier:(NSString *)identifier
                   complete:(QNUpCompletionHandler)completionHandler {
    NSString *desc = nil;
    if (completionHandler == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"no completionHandler"
                                     userInfo:nil];
        return YES;
    }
    if (input == nil) {
        desc = @"no input data";
    } else if (token == nil || [token isEqual:[NSNull null]] || [token isEqualToString:@""]) {
        desc = @"no token";
    }
    if (desc != nil) {
        QNAsyncRunInMain(^{
            QNResponseInfo *info = [Collector completeWithInvalidArgument:desc identifier:identifier];
            completionHandler(info, key, nil);
        });
        return YES;
    }
    return NO;
}

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
    
    NSString *identifier = [[NSUUID UUID] UUIDString];
    [Collector registerWithIdentifier:identifier token:token];
    [self putData:data fileName:nil key:key token:token identifier:identifier complete:completionHandler option:option];
}

- (void)putData:(NSData *)data
       fileName:(NSString *)fileName
            key:(NSString *)key
          token:(NSString *)token
     identifier:(NSString *)identifier
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {

    if ([QNUploadManager checkAndNotifyError:key token:token input:data identifier:identifier complete:completionHandler]) {
        return;
    }
    
    [[QNTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone
                                                               token:token];

    QNUpToken *t = [QNUpToken parse:token];
    if (t == nil) {
        QNAsyncRunInMain(^{
            QNResponseInfo *info = [Collector completeWithInvalidToken:@"invalid token" identifier:identifier];
            completionHandler(info, key, nil);
        });
        return;
    } else {
        [Collector update:CK_bucket value:t.bucket identifier:identifier];
        [Collector update:CK_key value:key identifier:identifier];
    }
    
    [_config.zone preQuery:t on:^(int code, QNHttpResponseInfo *httpResponseInfo) {
        [Collector addRequestWithType:QNRequestType_ucQuery httpResponseInfo:httpResponseInfo fileOffset:QN_IntNotSet targetRegionId:nil currentRegionId:nil identifier:identifier];
        if (code != 0) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        }
        if ([data length] == 0) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithZeroData:nil identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        }
        QNUpCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
            QNAsyncRunInMain(^{
                completionHandler(info, key, resp);
            });
        };
        QNFormUpload *up = [[QNFormUpload alloc]
                     initWithData:data
                          withKey:key
                        withFileName:fileName
                        withToken:t
                            withIdentifier:(NSString *)identifier
            withCompletionHandler:complete
                       withOption:option
                            withSessionManager:self.sessionManager
                withConfiguration:self.config];
        QNAsyncRun(^{
            [up put];
        });
    }];
}

- (void)putFileInternal:(id<QNFileDelegate>)file
                    key:(NSString *)key
                  token:(NSString *)token
             identifier:(NSString *)identifier
               complete:(QNUpCompletionHandler)completionHandler
                 option:(QNUploadOption *)option {
    
    @autoreleasepool {
        QNUpToken *t = [QNUpToken parse:token];
        if (t == nil) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithInvalidToken:@"invalid token" identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        } else {
            [Collector update:CK_bucket value:t.bucket identifier:identifier];
            [Collector update:CK_key value:key identifier:identifier];
        }

        [[QNTransactionManager shared] addDnsCheckAndPrefetchTransaction:self.config.zone
                                                                   token:token];
        
        [_config.zone preQuery:t on:^(int code, QNHttpResponseInfo *httpResponseInfo) {
            [Collector addRequestWithType:QNRequestType_ucQuery httpResponseInfo:httpResponseInfo fileOffset:QN_IntNotSet targetRegionId:nil currentRegionId:nil identifier:identifier];
            if (code != 0) {
                QNAsyncRunInMain(^{
                    QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:identifier];
                    completionHandler(info, key, nil);
                });
                return;
            }
            QNUpCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
                [file close];
                QNAsyncRunInMain(^{
                    completionHandler(info, key, resp);
                });
            };

            if ([file size] <= self.config.putThreshold) {
                NSError *error;
                NSData *data = [file readAllWithError:&error];
                if (error) {
                    QNAsyncRunInMain(^{
                        QNResponseInfo *info = [Collector completeWithLocalIOError:error identifier:identifier];
                        completionHandler(info, key, nil);
                    });
                    return;
                }
                NSString *fileName = [[file path] lastPathComponent];
                [self putData:data fileName:fileName key:key token:token identifier:identifier complete:completionHandler option:option];
                return;
            }

            NSString *recorderKey = key;
            if (self.config.recorder != nil && self.config.recorderKeyGen != nil) {
                recorderKey = self.config.recorderKeyGen(key, [file path]);
            }
            
            NSLog(@"recorder %@", self.config.recorder);
            
            if (self.config.useConcurrentResumeUpload) {
                QNConcurrentResumeUpload *up = [[QNConcurrentResumeUpload alloc]
                                                initWithFile:file
                                                withKey:key
                                                withToken:t
                                                withIdentifier:identifier
                                                withRecorder:self.config.recorder
                                                withRecorderKey:recorderKey
                                                withSessionManager:self.sessionManager
                                                withCompletionHandler:completionHandler
                                                withOption:option
                                                withConfiguration:self.config];
                QNAsyncRun(^{
                    [up run];
                });
            } else {
                QNResumeUpload *up = [[QNResumeUpload alloc]
                                      initWithFile:file
                                      withKey:key
                                      withToken:t
                                      withIdentifier:identifier
                                      withCompletionHandler:complete
                                      withOption:option
                                      withRecorder:self.config.recorder
                                      withRecorderKey:recorderKey
                                      withSessionManager:self.sessionManager
                                      withConfiguration:self.config];
                QNAsyncRun(^{
                    [up run];
                });
            }
        }];
    }
}

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option {
    
    NSString *identifier = [[NSUUID UUID] UUIDString];
    [Collector registerWithIdentifier:identifier token:token];
    if ([QNUploadManager checkAndNotifyError:key token:token input:filePath identifier:identifier complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block QNFile *file = [[QNFile alloc] init:filePath error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithFileError:error identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        }
        [self putFileInternal:file key:key token:token identifier:identifier complete:completionHandler option:option];
    }
}

#if !TARGET_OS_MACCATALYST
- (void)putALAsset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option {
#if __IPHONE_OS_VERSION_MIN_REQUIRED
    NSString *identifier = [[NSUUID UUID] UUIDString];
    [Collector registerWithIdentifier:identifier token:token];
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:asset identifier:identifier complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block QNALAssetFile *file = [[QNALAssetFile alloc] init:asset error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithFileError:error identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        }
        [self putFileInternal:file key:key token:token identifier:identifier complete:completionHandler option:option];
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
    NSString *identifier = [[NSUUID UUID] UUIDString];
    [Collector registerWithIdentifier:identifier token:token];
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:asset identifier:identifier complete:completionHandler]) {
        return;
    }

    @autoreleasepool {
        NSError *error = nil;
        __block QNPHAssetFile *file = [[QNPHAssetFile alloc] init:asset error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithFileError:error identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        }
        [self putFileInternal:file key:key token:token identifier:identifier complete:completionHandler option:option];
    }
#endif
}

- (void)putPHAssetResource:(PHAssetResource *)assetResource
                       key:(NSString *)key
                     token:(NSString *)token
                  complete:(QNUpCompletionHandler)completionHandler
                    option:(QNUploadOption *)option {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
    NSString *identifier = [[NSUUID UUID] UUIDString];
    [Collector registerWithIdentifier:identifier token:token];
    
    if ([QNUploadManager checkAndNotifyError:key token:token input:assetResource identifier:identifier complete:completionHandler]) {
        return;
    }
    @autoreleasepool {
        NSError *error = nil;
        __block QNPHAssetResource *file = [[QNPHAssetResource alloc] init:assetResource error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                QNResponseInfo *info = [Collector completeWithFileError:error identifier:identifier];
                completionHandler(info, key, nil);
            });
            return;
        }
        [self putFileInternal:file key:key token:token identifier:identifier complete:completionHandler option:option];
    }
#endif
}

@end
