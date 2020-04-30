//
//  QNUploadRequestTranscation.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestTranscation.h"

#import "QNCrc32.h"
#import "QNUrlSafeBase64.h"
#import "QNUpToken.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "QNUploadRequstState.h"

#import "QNResponseInfo.h"

#import "QNUploadData.h"
#import "QNHttpRequest.h"

@interface QNUploadRequestTranscation()

@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUploadRequstState *requestState;
@property(nonatomic,   copy)NSString *key;
@property(nonatomic, strong)QNUpToken *token;

// old server 不验证tls sni
@property(nonatomic, assign)BOOL isUserOldServer;
@property(nonatomic, strong)id <QNUploadServer> currentServer;
@property(nonatomic, strong)id <QNUploadRegion> region;

@property(nonatomic, strong)QNHttpRequest *httpRequest;

@end
@implementation QNUploadRequestTranscation

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                        region:(id <QNUploadRegion>)region
                           key:(NSString *)key
                         token:(QNUpToken *)token{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _requestState = [[QNUploadRequstState alloc] init];
        _region = region;
        _key = key;
        _token = token;
        _httpRequest = [[QNHttpRequest alloc] initWithConfig:config
                                                uploadOption:uploadOption
                                                requestState:_requestState];
    }
    return self;
}

//MARK: -- uc query
- (void)quertUploadHosts:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    [self quertUploadHosts:nil complete:complete];
}
- (void)quertUploadHosts:(QNResponseInfo *)lastResponseInfo
                complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    id <QNUploadServer> server = [self getNextServer:lastResponseInfo];
    if (server == nil) {
        return;
    }
    
    [self.httpRequest get:server
                   action:@""
                  headers:nil
                 complete:^(QNResponseInfo *responseInfo, NSDictionary *response) {
       
        if (responseInfo.isOK == false && self.config.allowBackupHost) {
            [self quertUploadHosts:responseInfo complete:complete];
        } else {
           if (complete) {
                complete(responseInfo, response);
            }
        }
    }];
}

//MARK: -- upload form
- (void)uploadFormData:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    [self uploadFormData:nil data:data fileName:fileName progress:progress complete:complete];
}
- (void)uploadFormData:(QNResponseInfo *)lastResponseInfo
                  data:(NSData *)data
              fileName:(NSString *)fileName
              progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
              complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    id <QNUploadServer> server = [self getNextServer:lastResponseInfo];
    if (server == nil) {
        return;
    }

    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    if (self.uploadOption.params) {
        [param addEntriesFromDictionary:self.uploadOption.params];
    }
    if (self.key && self.key.length > 0) {
        param[@"key"] = self.key;
    }
    param[@"token"] = self.token.token;
    if (self.uploadOption.checkCrc) {
        param[@"crc32"] = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:data]];
    }
    
    NSMutableData *body = [NSMutableData data];
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    NSString *disposition = @"Content-Disposition: form-data"
    for (NSString *paramsKey in params) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\n%@; name=\"%@\"\r\n\r\n", boundary, disposition, paramsKey];
        [body appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

        id value = [params objectForKey:paramsKey];
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
    header[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)postData.length];
    
    [self.httpRequest post:server
                    action:nil
                   headers:header
                      body:body
                  progress:progress
                  complete:^(QNResponseInfo * _Nonnull responseInfo, NSDictionary * _Nonnull response) {
        
        if (responseInfo.isOK == false && self.config.allowBackupHost) {
            [self uploadFormData:responseInfo data:data progress:progress complete:complete];
        } else {
           if (complete) {
                complete(responseInfo, response);
            }
        }
    }];
}

//MARK: -- 分块上传
- (void)makeBlock:(UInt32)blockSize
       firstChunk:(QNUploadChunk *)firstChunk
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    [self makeBlock:nil blockSize:blockSize firstChunk:firstChunk progress:progress complete:complete];
}
- (void)makeBlock:(QNResponseInfo *)lastResponseInfo
        blockSize:(UInt32)blockSize
       firstChunk:(QNUploadChunk *)firstChunk
         progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
         complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    id <QNUploadServer> server = [self getNextServer:lastResponseInfo];
    if (server == nil) {
        return;
    }
    
    NSDictionary *header = @{@"Authorization" : tokenUp,
                             @"Content-Type" : @"application/octet-stream"};
    NSString *action = [NSString stringWithFormat:@"/mkblk/%u", (unsigned int)blockSize];
    
    [self.httpRequest post:server
                    action:action
                   headers:header
                      body:firstChunk.info
                  progress:progress
                  complete:^(QNResponseInfo * _Nonnull responseInfo, NSDictionary * _Nonnull response) {
        
        if (responseInfo.isOK == false && self.config.allowBackupHost) {
            [self makeBlock:responseInfo blockSize:blockSize firstChunk:firstChunk progress:progress complete:complete];
        } else {
           if (complete) {
                complete(responseInfo, response);
            }
        }
    }];
}

- (void)uploadChunk:(NSString *)blockContext
              chunk:(QNUploadChunk *)chunk
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    [self uploadChunk:nil chunkContext:chunkContext chunk:chunk progress:progress complete:complete];
}
- (void)uploadChunk:(QNResponseInfo *)lastResponseInfo
       blockContext:(NSString *)blockContext
              chunk:(QNUploadChunk *)chunk
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    id <QNUploadServer> server = [self getNextServer:lastResponseInfo];
    if (server == nil) {
        return;
    }
    
    NSDictionary *header = @{@"Authorization" : tokenUp,
                             @"Content-Type" : @"application/octet-stream"};
    NSString *action = [NSString stringWithFormat:@"/bput/%@/%u", blockContext,  (unsigned int)chunk.offset];
    
    [self.httpRequest post:server
                    action:action
                   headers:header
                      body:firstChunk.info
                  progress:progress
                  complete:^(QNResponseInfo * _Nonnull responseInfo, NSDictionary * _Nonnull response) {
        
        if (responseInfo.isOK == false && self.config.allowBackupHost) {
            [self makeBlock:responseInfo blockSize:blockSize firstChunk:firstChunk progress:progress complete:complete];
        } else {
           if (complete) {
                complete(responseInfo, response);
            }
        }
    }];
}

- (void)makeFile:(UInt32)fileSize
        fileName:(NSString *)fileName
       blockList:(NSArray <QNUploadBlock *> *)blockList
        complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    [self makeFile:nil fileSize:fileSize fileName:fileName blockList:blockList complete:complete];
}
- (void)makeFile:(QNResponseInfo *)lastResponseInfo
        fileSize:(UInt32)fileSize
        fileName:(NSString *)fileName
        blockList:(NSArray <QNUploadBlock *> *)blockList
        complete:(void(^)(QNResponseInfo *responseInfo, NSDictionary *response))complete{
    
    id <QNUploadServer> server = [self getNextServer:lastResponseInfo];
    if (server == nil) {
        return;
    }
    
    NSMutableArray *blockContextList = [NSMutableArray array];
    for (QNUploadBlock *block in blockList) {
        if (block.context) {
            [blockContextList addObject:block.context];
        }
    }
    
    NSDictionary *header = @{@"Authorization" : tokenUp,
                             @"Content-Type" : @"application/octet-stream"};
    
    NSString *mimeType = [[NSString alloc] initWithFormat:@"mimeType/%@", [QNUrlSafeBase64 encodeString:self.uploadOption.mimeType]];
    NSString *fileName = [[NSString alloc] initWithFormat:@"fname/%@", [QNUrlSafeBase64 encodeString:fileName]];
    NSString *action = [NSString stringWithFormat:@"/mkfile/%u/%@/%@", chunkContext,  (unsigned int)fileSize, mimeType, fileName];
    
    NSMutableData *body = [NSMutableData data];
    NSString *bodyString = [self.contexts componentsJoinedByString:@","];
    [body appendData:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self.httpRequest post:server
                    action:action
                   headers:header
                      body:firstChunk.info
                  progress:progress
                  complete:^(QNResponseInfo * _Nonnull responseInfo, NSDictionary * _Nonnull response) {
        
        if (responseInfo.isOK == false && self.config.allowBackupHost) {
            [self makeBlock:responseInfo blockSize:blockSize firstChunk:firstChunk progress:progress complete:complete];
        } else {
           if (complete) {
                complete(responseInfo, response);
            }
        }
    }];
    
}


//MARK: --
- (id <QNUploadServer>)getNextServer:(QNResponseInfo *)responseInfo{

    if (responseInfo == nil) {
        return [self.region getNextServer:NO freezeServer:nil];
    }
    
    if (self.config.allowBackupHost == NO) {
        return nil;
    }
    if (responseInfo.isTlsError == YES) {
        return [self.region getNextServer:YES freezeServer:self.currentServer];
    } else {
        return [self.region getNextServer:self.isUserOldServer freezeServer:self.currentServer];
    }
}

@end
