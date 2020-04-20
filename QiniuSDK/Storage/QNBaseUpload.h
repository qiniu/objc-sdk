//
//  QNBaseUpload.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNConfiguration.h"
#import "QNCrc32.h"
#import "QNRecorderDelegate.h"
#import "QNHttpResponseInfo.h"
#import "QNSessionManager.h"
#import "QNUpToken.h"
#import "QNUrlSafeBase64.h"
#import "QNAsyncRun.h"
#import "QNUploadInfoCollector.h"
#import "QNUploadManager.h"
#import "QNUploadOption.h"

@interface QNBaseUpload : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *access; //AK
@property (nonatomic, assign) UInt32 size;
@property (nonatomic, strong) QNSessionManager *sessionManager;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpCompletionHandler complete;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, assign) QNZoneInfoType currentZoneType;
@property (nonatomic, assign) QNRequestType requestType;

- (void)collectHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(uint64_t)fileOffset;

- (void)collectUploadQualityInfo;

- (void)run;

@end
