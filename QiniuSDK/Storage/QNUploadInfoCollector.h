//
//  QNUploadInfoCollector.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadInfoReporter.h"

#define Collector [QNUploadInfoCollector sharedInstance]

typedef NSString QNCollectKey;

// update key
extern QNCollectKey *const CK_targetRegionId;
extern QNCollectKey *const CK_currentRegionId;
extern QNCollectKey *const CK_result;
extern QNCollectKey *const CK_cloudType;
extern QNCollectKey *const CK_recoveredFrom;
extern QNCollectKey *const CK_fileSize;
extern QNCollectKey *const CK_blockApiVersion;

// append key
extern QNCollectKey *const CK_blockBytesSent;
extern QNCollectKey *const CK_totalBytesSent;
extern QNCollectKey *const CK_requestItem;

@interface QNUploadInfoCollector : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;
- (void)registerWithIdentifier:(NSString *)identifier token:(NSString *)token;
- (void)update:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier;
- (void)append:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier;
- (void)resignWithIdentifier:(NSString *)identifier result:(NSString *)result;

@end
