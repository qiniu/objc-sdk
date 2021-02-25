//
//  QNRequestTransaction.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNRequestTransaction.h"

#import "QNDefine.h"
#import "QNUtils.h"
#import "QNCrc32.h"
#import "NSData+QNMD5.h"
#import "QNUrlSafeBase64.h"
#import "QNUpToken.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "QNZoneInfo.h"
#import "QNUserAgent.h"
#import "QNResponseInfo.h"
#import "QNUploadRequestState.h"

#import "QNUploadDomainRegion.h"
#import "QNHttpRegionRequest.h"

@interface QNRequestTransaction()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic,   copy)NSString *key;
@property(nonatomic, strong)QNUpToken *token;

@property(nonatomic, strong)QNUploadRequestInfo *requestInfo;
@property(nonatomic, strong)QNUploadRequestState *requestState;
@property(nonatomic, strong)QNHttpRegionRequest *regionRequest;

@end
@implementation QNRequestTransaction

- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                     regionId:(NSString * _Nullable)regionId
                        token:(QNUpToken *)token{
    return [self initWithConfig:[QNConfiguration defaultConfiguration]
                   uploadOption:[QNUploadOption defaultOptions]
                          hosts:hosts
                       regionId:regionId
                            key:nil
                          token:token];
}

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                      regionId:(NSString * _Nullable)regionId
                           key:(NSString * _Nullable)key
                         token:(nonnull QNUpToken *)token{
    
    QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
    [region setupRegionData:[QNZoneInfo zoneInfoWithMainHosts:hosts regionId:regionId]];
    return [self initWithConfig:config
                   uploadOption:uploadOption
                   targetRegion:region
                  currentRegion:region
                            key:key
                          token:token];
}

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  targetRegion:(id <QNUploadRegion>)targetRegion
                 currentRegion:(id <QNUploadRegion>)currentRegion
                           key:(NSString *)key
                         token:(QNUpToken *)token{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _requestState = [[QNUploadRequestState alloc] init];
        _key = key;
        _token = token;
        _requestInfo = [[QNUploadRequestInfo alloc] init];
        _requestInfo.targetRegionId = targetRegion.zoneInfo.regionId;
        _requestInfo.currentRegionId = currentRegion.zoneInfo.regionId;
        _requestInfo.bucket = token.bucket;
        _requestInfo.key = key;
        _regionRequest = [[QNHttpRegionRequest alloc] initWithConfig:config
                                                        uploadOption:uploadOption
                                                               token:token
                                                              region:currentRegion
                                                         requestInfo:_requestInfo
                                                        requestState:_requestState];
    }
    return self;
}

//MARK: -- uc query
- (void)queryUploadHosts:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeUCQuery;
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)!responseInfo.isOK;
    };
    
    NSDictionary *header = @{@"User-Agent" : [kQNUserAgent getUserAgent:self.token.token]};
    NSString *action = [NSString stringWithFormat:@"/v4/query?ak=%@&bucket=%@&sdk_name=%@&sdk_version=%@", self.token.access, self.token.bucket, [QNUtils sdkLanguage], [QNUtils sdkVersion]];
    [self.regionRequest get:action
                    headers:header
                shouldRetry:shouldRetry
                   complete:complete];
}

//MARK: -- upload form
- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRequestTransactionCompleteHandler)complete{

    self.requestInfo.requestType = QNUploadRequestTypeForm;
    
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    if (self.uploadOption.params) {
        [param addEntriesFromDictionary:self.uploadOption.params];
    }
    if (self.uploadOption.metaDataParam) {
        [param addEntriesFromDictionary:self.uploadOption.metaDataParam];
    }
    if (self.key && self.key.length > 0) {
        param[@"key"] = self.key;
    }
    param[@"token"] = self.token.token ?: @"";
    if (self.uploadOption.checkCrc) {
        param[@"crc32"] = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:data]];
    }
    
    NSMutableData *body = [NSMutableData data];
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    NSString *disposition = @"Content-Disposition: form-data";
    for (NSString *paramsKey in param) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\n%@; name=\"%@\"\r\n\r\n", boundary, disposition, paramsKey];
        [body appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

        id value = [param objectForKey:paramsKey];
        if ([value isKindOfClass:[NSString class]]) {
            [body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSData class]]) {
            [body appendData:value];
        }
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    fileName = [QNUtils formEscape:fileName];
    
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\n%@; name=\"%@\"; filename=\"%@\"\nContent-Type:%@\r\n\r\n", boundary, disposition, @"file", fileName, self.uploadOption.mimeType];
    [body appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Content-Type"] = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    header[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)!responseInfo.isOK;
    };
    
    [self.regionRequest post:nil
                     headers:header
                        body:body
                 shouldRetry:shouldRetry
                    progress:progress
                    complete:complete];
}

//MARK: -- 分块上传
- (void)makeBlock:(long long)blockOffset
        blockSize:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeMkblk;
    self.requestInfo.fileOffset = @(blockOffset);
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];
    
    NSString *action = [NSString stringWithFormat:@"/mkblk/%u", (unsigned int)blockSize];
    
    NSString *chunkCrc = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:firstChunkData]];
    
    kQNWeakSelf;
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        kQNStrongSelf;
        
        NSString *ctx = response[@"ctx"];
        NSString *crcServer = [NSString stringWithFormat:@"%@", response[@"crc32"]];
        return (BOOL)(responseInfo.isOK == false || (responseInfo.isOK && (!ctx || (self.uploadOption.checkCrc && ![chunkCrc isEqualToString:crcServer]))));
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:firstChunkData
                 shouldRetry:shouldRetry
                    progress:progress
                    complete:complete];
}

- (void)uploadChunk:(NSString *)blockContext
        blockOffset:(long long)blockOffset
          chunkData:(NSData *)chunkData
        chunkOffset:(long long)chunkOffset
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeBput;
    self.requestInfo.fileOffset = @(blockOffset + chunkOffset);
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];
    
    NSString *action = [NSString stringWithFormat:@"/bput/%@/%lld", blockContext,  chunkOffset];
    
    NSString *chunkCrc = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:chunkData]];
    
    kQNWeakSelf;
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        kQNStrongSelf;
        
        NSString *ctx = response[@"ctx"];
        NSString *crcServer = [NSString stringWithFormat:@"%@", response[@"crc32"]];
        return (BOOL)(responseInfo.isOK == false || (responseInfo.isOK && (!ctx || (self.uploadOption.checkCrc && ![chunkCrc isEqualToString:crcServer]))));
    };
    
    [self.regionRequest post:action
                     headers:header
                      body:chunkData
                 shouldRetry:shouldRetry
                    progress:progress
                    complete:complete];
}

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeMkfile;
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];
    
    NSString *mimeType = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.uploadOption.mimeType]];

    __block NSString *action = [[NSString alloc] initWithFormat:@"/mkfile/%lld%@", fileSize, mimeType];

    if (self.key != nil) {
        NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNUrlSafeBase64 encodeString:self.key]];
        action = [NSString stringWithFormat:@"%@%@", action, keyStr];
    }

    [self.uploadOption.params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        action = [NSString stringWithFormat:@"%@/%@/%@", action, key, [QNUrlSafeBase64 encodeString:obj]];
    }];
    
    [self.uploadOption.metaDataParam enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        action = [NSString stringWithFormat:@"%@/%@/%@", action, key, [QNUrlSafeBase64 encodeString:obj]];
    }];

    //添加路径
    NSString *fname = [[NSString alloc] initWithFormat:@"/fname/%@", [QNUrlSafeBase64 encodeString:fileName]];
    action = [NSString stringWithFormat:@"%@%@", action, fname];

    NSMutableData *body = [NSMutableData data];
    NSString *bodyString = [blockContexts componentsJoinedByString:@","];
    [body appendData:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:body
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:complete];
}


- (void)initPart:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeInitParts;
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];

    NSString *buckets = [[NSString alloc] initWithFormat:@"/buckets/%@", self.token.bucket];
    NSString *objects = [[NSString alloc] initWithFormat:@"/objects/%@", [self resumeV2EncodeKey:self.key]];;
    NSString *action  = [[NSString alloc] initWithFormat:@"%@%@/uploads", buckets, objects];

    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:nil
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)uploadPart:(NSString *)uploadId
         partIndex:(NSInteger)partIndex
          partData:(NSData *)partData
          progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
          complete:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeUploadPart;
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/octet-stream";
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];
    if (self.uploadOption.checkCrc) {
        NSString *md5 = [[partData qn_md5] lowercaseString];
        if (md5) {
            header[@"Content-MD5"] = md5;
        }
    }
    NSString *buckets = [[NSString alloc] initWithFormat:@"/buckets/%@", self.token.bucket];
    NSString *objects = [[NSString alloc] initWithFormat:@"/objects/%@", [self resumeV2EncodeKey:self.key]];;
    NSString *uploads = [[NSString alloc] initWithFormat:@"/uploads/%@", uploadId];
    NSString *partNumber = [[NSString alloc] initWithFormat:@"/%ld", (long)partIndex];
    NSString *action = [[NSString alloc] initWithFormat:@"%@%@%@%@", buckets, objects, uploads, partNumber];
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        NSString *etag = [NSString stringWithFormat:@"%@", response[@"etag"]];
        NSString *serverMD5 = [NSString stringWithFormat:@"%@", response[@"md5"]];
        return (BOOL)(!responseInfo.isOK || !etag || !serverMD5);
    };
    
    [self.regionRequest put:action
                    headers:header
                       body:partData
                shouldRetry:shouldRetry
                   progress:progress
                   complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)completeParts:(NSString *)fileName
             uploadId:(NSString *)uploadId
        partInfoArray:(NSArray <NSDictionary *> *)partInfoArray
             complete:(QNRequestTransactionCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeCompletePart;
    
    if (!partInfoArray || partInfoArray.count == 0) {
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithInvalidArgument:@"partInfoArray"];
        if (complete) {
            complete(responseInfo, nil, responseInfo.responseDictionary);
        }
        return;
    }
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Authorization"] = token;
    header[@"Content-Type"] = @"application/json";
    header[@"User-Agent"] = [kQNUserAgent getUserAgent:self.token.token];
    
    NSString *buckets = [[NSString alloc] initWithFormat:@"/buckets/%@", self.token.bucket];
    NSString *objects = [[NSString alloc] initWithFormat:@"/objects/%@", [self resumeV2EncodeKey:self.key]];
    NSString *uploads = [[NSString alloc] initWithFormat:@"/uploads/%@", uploadId];
    
    NSString *action = [[NSString alloc] initWithFormat:@"%@%@%@", buckets, objects, uploads];

    NSMutableDictionary *bodyDictionary = [NSMutableDictionary dictionary];
    if (partInfoArray) {
        bodyDictionary[@"parts"] = partInfoArray;
    }
    if (fileName) {
        bodyDictionary[@"fname"] = fileName;
    }
    if (self.uploadOption.mimeType) {
        bodyDictionary[@"mimeType"] = self.uploadOption.mimeType;
    }
    if (self.uploadOption.params) {
        bodyDictionary[@"customVars"] = self.uploadOption.params;
    }
    if (self.uploadOption.metaDataParam) {
        bodyDictionary[@"metaData"] = self.uploadOption.metaDataParam;
    }
    
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:bodyDictionary
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    if (error) {
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithLocalIOError:error.description];
        if (complete) {
            complete(responseInfo, nil, responseInfo.responseDictionary);
        }
        return;
    }
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        return (BOOL)(!responseInfo.isOK);
    };
    
    [self.regionRequest post:action
                     headers:header
                        body:body
                 shouldRetry:shouldRetry
                    progress:nil
                    complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (NSString *)resumeV2EncodeKey:(NSString *)key{
    NSString *encodeKey = nil;
    if (!self.key) {
        encodeKey = @"~";
    } else if (self.key.length == 0) {
        encodeKey = @"";
    } else {
        encodeKey = [QNUrlSafeBase64 encodeString:self.key];
    }
    return encodeKey;
}

@end
