//
//  QNRequestTranscation.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNRequestTranscation.h"

#import "QNCrc32.h"
#import "QNUrlSafeBase64.h"
#import "QNUpToken.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "QNZoneInfo.h"

#import "QNResponseInfo.h"

#import "QNUploadFixedHostRegion.h"
#import "QNHttpRegionRequest.h"

@interface QNRequestTranscation()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequestInfo *requestInfo;
@property(nonatomic, strong)QNUploadRequstState *requestState;
@property(nonatomic,   copy)NSString *key;
@property(nonatomic, strong)QNUpToken *token;

@property(nonatomic, strong)QNHttpRegionRequest *httpRequest;

@end
@implementation QNRequestTranscation

- (instancetype)initWithHosts:(NSArray <NSString *> *)hosts
                        token:(QNUpToken *)token{
    return [self initWithConfig:[QNConfiguration defaultConfiguration]
                   uploadOption:[QNUploadOption defaultOptions]
                          hosts:hosts
                            key:nil
                          token:token];
}

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         hosts:(NSArray <NSString *> *)hosts
                           key:(NSString * _Nullable)key
                         token:(QNUpToken *)token{
    
    QNUploadFixedHostRegion *region = [QNUploadFixedHostRegion fixedHostRegionWithHosts:hosts];
    return [self initWithConfig:config
                   uploadOption:uploadOption
                   targetRegion:region
                   currentegion:region
                            key:key
                          token:token];
}

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                  targetRegion:(id <QNUploadRegion>)targetRegion
                  currentegion:(id <QNUploadRegion>)currentegion
                           key:(NSString *)key
                         token:(QNUpToken *)token{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _requestState = [[QNUploadRequstState alloc] init];
        _key = key;
        _token = token;
        _requestInfo = [[QNUploadRequestInfo alloc] init];
        _requestInfo.targetRegionId = targetRegion.zoneInfo.zoneRegionId;
        _requestInfo.currentRegionId = currentegion.zoneInfo.zoneRegionId;
        _requestInfo.bucket = token.bucket;
        _requestInfo.key = key;
        _httpRequest = [[QNHttpRegionRequest alloc] initWithConfig:config
                                                      uploadOption:uploadOption
                                                             token:token
                                                            region:currentegion
                                                       requestInfo:_requestInfo
                                                      requestState:_requestState];
    }
    return self;
}

//MARK: -- uc query
- (void)quertUploadHosts:(QNRequestTranscationCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeUCQuery;
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        if (responseInfo.isOK == false) {
            return YES;
        } else {
            return NO;
        }
    };
    NSString *action = [NSString stringWithFormat:@"/v3/query?ak=%@&bucket=%@", self.token.access, self.token.bucket];
    [self.httpRequest get:action
                  headers:nil
              shouldRetry:shouldRetry
                 complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

//MARK: -- upload form
- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(QNRequestTranscationCompleteHandler)complete{

    self.requestInfo.requestType = QNUploadRequestTypeForm;
    
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    if (self.uploadOption.params) {
        [param addEntriesFromDictionary:self.uploadOption.params];
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
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\n%@; name=\"%@\"; filename=\"%@\"\nContent-Type:%@\r\n\r\n", boundary, disposition, @"file", fileName, self.uploadOption.mimeType];
    [body appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    header[@"Content-Type"] = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    header[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        if (responseInfo.isOK == false) {
            return YES;
        } else {
            return NO;
        }
    };
    
    [self.httpRequest post:nil
                   headers:header
                      body:body
               shouldRetry:shouldRetry
                  progress:progress
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        complete(responseInfo, metrics, response);
    }];
}

//MARK: -- 分块上传
- (void)makeBlock:(long long)blockOffset
        blockSize:(long long)blockSize
   firstChunkData:(NSData *)firstChunkData
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(QNRequestTranscationCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeForm;
    self.requestInfo.fileOffset = @(blockOffset);
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSDictionary *header = @{@"Authorization" : token,
                             @"Content-Type" : @"application/octet-stream"};
    NSString *action = [NSString stringWithFormat:@"/mkblk/%u", (unsigned int)blockSize];
    
    NSString *chunkCrc = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:firstChunkData]];
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        
        NSString *ctx = response[@"ctx"];
        NSString *crcServer = [NSString stringWithFormat:@"%@", response[@"crc32"]];
        if (responseInfo.isOK == false
            || (responseInfo.isOK && (!ctx || (self.uploadOption.checkCrc && ![chunkCrc isEqualToString:crcServer])))) {
            return YES;
        } else {
            return NO;
        }
    };
    
    [self.httpRequest post:action
                   headers:header
                      body:firstChunkData
               shouldRetry:shouldRetry
                  progress:progress
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)uploadChunk:(NSString *)blockContext
        blockOffset:(long long)blockOffset
          chunkData:(NSData *)chunkData
        chunkOffest:(long long)chunkOffest
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(QNRequestTranscationCompleteHandler)complete{
    
    self.requestInfo.requestType = QNUploadRequestTypeForm;
    self.requestInfo.fileOffset = @(blockOffset + chunkOffest);
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSDictionary *header = @{@"Authorization" : token,
                             @"Content-Type" : @"application/octet-stream"};
    
    NSString *action = [NSString stringWithFormat:@"/bput/%@/%lld", blockContext,  chunkOffest];
    
    NSString *chunkCrc = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:chunkData]];
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        NSString *ctx = response[@"ctx"];
        NSString *crcServer = [NSString stringWithFormat:@"%@", response[@"crc32"]];
        if (responseInfo.isOK == false
            || (responseInfo.isOK && (!ctx || (self.uploadOption.checkCrc && ![chunkCrc isEqualToString:crcServer])))) {
            return YES;
        } else {
            return NO;
        }
    };
    
    [self.httpRequest post:action
                   headers:header
                      body:chunkData
               shouldRetry:shouldRetry
                  progress:progress
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}

- (void)makeFile:(long long)fileSize
        fileName:(NSString *)fileName
   blockContexts:(NSArray <NSString *> *)blockContexts
        complete:(QNRequestTranscationCompleteHandler)complete{
    
    NSString *token = [NSString stringWithFormat:@"UpToken %@", self.token.token];
    NSDictionary *header = @{@"Authorization" : token,
                             @"Content-Type" : @"application/octet-stream"};
    
    NSString *mimeType = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.uploadOption.mimeType]];

    __block NSString *action = [[NSString alloc] initWithFormat:@"/mkfile/%lld%@", fileSize, mimeType];

    if (self.key != nil) {
        NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNUrlSafeBase64 encodeString:self.key]];
        action = [NSString stringWithFormat:@"%@%@", action, keyStr];
    }

    [self.uploadOption.params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        action = [NSString stringWithFormat:@"%@/%@/%@", action, key, [QNUrlSafeBase64 encodeString:obj]];
    }];

    //添加路径
    NSString *fname = [[NSString alloc] initWithFormat:@"/fname/%@", [QNUrlSafeBase64 encodeString:fileName]];
    action = [NSString stringWithFormat:@"%@%@", action, fname];

    NSMutableData *body = [NSMutableData data];
    NSString *bodyString = [blockContexts componentsJoinedByString:@","];
    [body appendData:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    BOOL (^shouldRetry)(QNResponseInfo *, NSDictionary *) = ^(QNResponseInfo * responseInfo, NSDictionary * response){
        if (responseInfo.isOK == false) {
            return YES;
        } else {
            return NO;
        }
    };
    
    [self.httpRequest post:action
                   headers:header
                      body:body
               shouldRetry:shouldRetry
                  progress:nil
                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        complete(responseInfo, metrics, response);
    }];
}




@end