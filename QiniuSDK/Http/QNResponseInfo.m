//
//  QNResponseInfo.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//
#import "QNErrorCode.h"
#import "QNResponseInfo.h"
#import "QNUserAgent.h"
#import "QNUtils.h"

static NSString *kQNErrorDomain = @"qiniu.com";

@interface QNResponseInfo ()

@property (assign) int statusCode;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *reqId;
@property (nonatomic, copy) NSString *xlog;
@property (nonatomic, copy) NSString *xvia;
@property (nonatomic, copy) NSError *error;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *id;
@property (assign) UInt64 timeStamp;

@end

@implementation QNResponseInfo
+ (instancetype)successResponse{
    QNResponseInfo *responseInfo = [[QNResponseInfo alloc] init];
    responseInfo.statusCode = 200;
    responseInfo.message = @"inter:ok";
    responseInfo.xlog = @"inter:xlog";
    responseInfo.reqId = @"inter:reqid";
    return responseInfo;
}

+ (instancetype)cancelResponse {
    return [QNResponseInfo errorResponseInfo:kQNRequestCancelled
                                   errorDesc:@"cancelled by user"];
}

+ (instancetype)responseInfoWithNetworkError:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNNetworkError
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNInvalidArgument
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc {
    return [QNResponseInfo errorResponseInfo:kQNInvalidToken
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithFileError:(NSError *)error {
    return [QNResponseInfo errorResponseInfo:kQNFileError
                                   errorDesc:nil
                                       error:error];
}

+ (instancetype)responseInfoOfZeroData:(NSString *)path {
    NSString *desc;
    if (path == nil) {
        desc = @"data size is 0";
    } else {
        desc = [[NSString alloc] initWithFormat:@"file %@ size is 0", path];
    }
    return [QNResponseInfo errorResponseInfo:kQNZeroDataSize
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithLocalIOError:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNLocalIOError
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithMaliciousResponseError:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNMaliciousResponseError
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithNoUsableHostError:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNSDKInteriorError
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithSDKInteriorError:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNSDKInteriorError
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithUnexpectedSysCallError:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:kQNUnexpectedSysCallError
                                   errorDesc:desc];
}

+ (instancetype)errorResponseInfo:(int)errorType
                        errorDesc:(NSString *)errorDesc{
    return [self errorResponseInfo:errorType errorDesc:errorDesc error:nil];
}

+ (instancetype)errorResponseInfo:(int)errorType
                        errorDesc:(NSString *)errorDesc
                            error:(NSError *)error{
    QNResponseInfo *response = [[QNResponseInfo alloc] init];
    response.statusCode = errorType;
    response.message = errorDesc;
    if (error) {
       response.error = error;
    } else {
        NSError *error = [[NSError alloc] initWithDomain:kQNErrorDomain
                                                    code:errorType
                                                userInfo:@{ @"error" : response.message ?: @"error" }];
        response.error = error;
    }
    
    return response;
}

- (instancetype)initWithResponseInfoHost:(NSString *)host
                                response:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error {
    
    self = [super init];
    if (self) {
        
        _host = host;
        _timeStamp = [[NSDate date] timeIntervalSince1970];
        
        if (response) {
            
            int statusCode = (int)[response statusCode];
            NSDictionary *headers = [response allHeaderFields];
            _responseHeader = [headers copy];
            _statusCode = statusCode;
            _reqId = headers[@"x-reqid"];
            _xlog = headers[@"x-log"];
            _xvia = headers[@"x-via"] ?: headers[@"x-px"] ?: headers[@"fw-via"];
            if (_statusCode == 200 && _reqId == nil && _xlog == nil) {
                _statusCode = kQNMaliciousResponseError;
                _message = @"this is a malicious response";
                _responseDictionary = nil;
                _error = [[NSError alloc] initWithDomain:kQNErrorDomain code:_statusCode userInfo:@{@"error" : _message}];
            } else if (error) {
                _error = error;
                _statusCode = (int)error.code;
                _message = [NSString stringWithFormat:@"%@", error];
                _responseDictionary = nil;
            } else {
                NSMutableDictionary *errorUserInfo = [@{@"errorHost" : host ?: @""} mutableCopy];
                if (!body) {
                    _message = @"no response data";
                    _error = nil;
                    _responseDictionary = nil;
                } else {
                    NSError *tmp = nil;
                    NSDictionary *responseInfo = nil;
                    responseInfo = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableLeaves error:&tmp];
                    if (tmp){
                        _message = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
                        _error = nil;
                        _responseDictionary = nil;
                    } else if (statusCode >= 200 && statusCode < 300) {
                        _error = nil;
                        _message = @"ok";
                        _responseDictionary = responseInfo;
                    } else {
                        NSString *errorString = responseInfo[@"error"];
                        if (errorString) {
                            [errorUserInfo setDictionary:@{@"error" : errorString}];
                            _message = errorString;
                            _error = [[NSError alloc] initWithDomain:kQNErrorDomain code:statusCode userInfo:errorUserInfo];
                        } else {
                            _message = errorString;
                            _error = nil;
                        }
                        
                        _responseDictionary = responseInfo;
                    }
                }
            }
        } else if (error) {
            _error = error;
            _statusCode = (int)error.code;
            _message = [NSString stringWithFormat:@"%@", error];
            _responseDictionary = nil;
        } else {
            _statusCode = kQNUnexpectedSysCallError;
            _message = @"no response";
        }
    }
    return self;
}

- (BOOL)isCancelled {
    return _statusCode == kQNRequestCancelled || _statusCode == -999;
}

- (BOOL)isTlsError{
    if (_statusCode == NSURLErrorServerCertificateHasBadDate
        || _statusCode == NSURLErrorClientCertificateRejected
        || _statusCode == NSURLErrorClientCertificateRequired) {
        return true;
    } else {
        return false;
    }
}

- (BOOL)isQiniu {
    // reqId is nill means the server is not qiniu
    return ![self isNotQiniu];
}

- (BOOL)isNotQiniu {
    // reqId is nill means the server is not qiniu
    return (_statusCode == kQNMaliciousResponseError) || (_statusCode > 0 && _reqId == nil && _xlog == nil);
}

- (BOOL)isOK {
    return (_statusCode >= 200 && _statusCode < 300) && _error == nil && (_reqId != nil || _xlog != nil);
}

- (BOOL)couldRetry {
    if ([self isQiniu] && (self.isCancelled
        || _statusCode == 100
        || (_statusCode > 300 && _statusCode < 400)
        || (_statusCode > 400 && _statusCode < 500 && _statusCode != 406)
        || _statusCode == 501 || _statusCode == 573
        || _statusCode == 608 || _statusCode == 612 || _statusCode == 614 || _statusCode == 616
        || _statusCode == 619 || _statusCode == 630 || _statusCode == 631 || _statusCode == 640
        || _statusCode == 701
        || (_statusCode != kQNLocalIOError && _statusCode != kQNUnexpectedSysCallError && _statusCode < -1 && _statusCode > -1000))) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)couldRegionRetry{
    if (![self couldRetry] || _statusCode == 400 || _statusCode == 579) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)couldHostRetry{
    if ([self isNotQiniu] || ![self couldRegionRetry]
        || _statusCode == 502 || _statusCode == 503 || _statusCode == 571 || _statusCode == 599) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)canConnectToHost{
    if (_statusCode > 99 || self.isCancelled) {
        return true;
    } else {
        return false;
    }
}

- (BOOL)isHostUnavailable{
    // 基本不可恢复，注：会影响下次请求，范围太大可能会造成大量的timeout
    if (_statusCode == 502 || _statusCode == 503 || _statusCode == 504 || _statusCode == 599) {
        return true;
    } else {
        return false;
    }
}

- (BOOL)isConnectionBroken {
    return _statusCode == kQNNetworkError || _statusCode == NSURLErrorNotConnectedToInternet;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@= id: %@, ver: %@, status: %d, requestId: %@, xlog: %@, xvia: %@, host: %@ time: %llu error: %@>", NSStringFromClass([self class]), _id, [QNUtils sdkVersion], _statusCode, _reqId, _xlog, _xvia, _host, _timeStamp, _error];
}

@end
