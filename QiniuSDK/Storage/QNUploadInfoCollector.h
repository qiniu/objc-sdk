//
//  QNUploadInfoCollector.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define Collector [QNUploadInfoCollector sharedInstance]

@class QNHttpResponseInfo;
@class QNResponseInfo;

// request types
typedef enum : NSUInteger {
    QNRequestType_form,
    QNRequestType_mkblk,
    QNRequestType_bput,
    QNRequestType_mkfile,
    QNRequestType_put,
    QNRequestType_initParts,
    QNRequestType_uploadParts,
    QNRequestType_completeParts,
    QNRequestType_ucQuery,
    QNRequestType_httpdnsQuery
} QNRequestType;

typedef NSString QNCollectKey;

// update key
extern QNCollectKey *const CK_bucket;
extern QNCollectKey *const CK_key;
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

@interface QNUploadInfoCollector : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

- (void)registerWithIdentifier:(NSString *)identifier token:(NSString *)token;

- (void)update:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier;
- (void)append:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier;
- (void)addRequestWithType:(QNRequestType)upType httpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(uint64_t)fileOffset targetRegionId:(NSString *)targetRegionId currentRegionId:(NSString *)currentRegionId identifier:(NSString *)identifier;

- (QNResponseInfo *)completeWithHttpResponseInfo:(QNHttpResponseInfo *)lastHttpResponseInfo identifier:(NSString *)identifier;
- (QNResponseInfo *)completeWithInvalidArgument:(NSString *)text identifier:(NSString *)identifier;
- (QNResponseInfo *)completeWithInvalidToken:(NSString *)text identifier:(NSString *)identifier;
- (QNResponseInfo *)completeWithFileError:(NSError *)error identifier:(NSString *)identifier;
- (QNResponseInfo *)completeWithZeroData:(NSString *)path identifier:(NSString *)identifier;
- (QNResponseInfo *)userCancel:(NSString *)identifier;

@end
