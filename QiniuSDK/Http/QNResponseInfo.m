//
//  QNResponseInfo.m
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResponseInfo.h"
#import "QNHttpResponseInfo.h"
#import "QNUserAgent.h"
#import "QNVersion.h"

const int kQNZeroDataSize = -6;
const int kQNInvalidToken = -5;
const int kQNFileError = -4;
const int kQNInvalidArgument = -3;
const int kQNRequestCancelled = -2;
const int kQNNetworkError = -1;

static NSString *kQNErrorDomain = @"qiniu.com";

@interface QNResponseInfo ()

@property (assign) int statusCode;
@property (nonatomic, copy) NSString *msg;
@property (nonatomic, copy) NSString *msgDetail;
@property (nonatomic, copy) NSString *reqId;
@property (nonatomic, copy) NSString *xlog;
@property (nonatomic, copy) NSString *xvia;
@property (nonatomic, copy) NSError *error;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *id;
@property (assign) UInt64 timeStamp;

@end

@implementation QNResponseInfo

+ (instancetype)cancelResponse {
    return [QNResponseInfo errorResponseInfo:QNResponseInfoErrorTypeUserCanceled
                                   errorDesc:@"cancelled by user"];
}

+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc{
    return [QNResponseInfo errorResponseInfo:QNResponseInfoErrorTypeInvalidArgs
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc {
    return [QNResponseInfo errorResponseInfo:QNResponseInfoErrorTypeInvalidToken
                                   errorDesc:desc];
}

+ (instancetype)responseInfoWithFileError:(NSError *)error {
    return [QNResponseInfo errorResponseInfo:QNResponseInfoErrorTypeInvalidFile
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
    return [QNResponseInfo errorResponseInfo:QNResponseInfoErrorTypeZeroSizeFile
                                   errorDesc:desc];
}

+ (instancetype)errorResponseInfo:(QNResponseInfoErrorType)errorType
                        errorDesc:(NSString *)errorDesc{
    return [self errorResponseInfo:errorType errorDesc:errorDesc error:nil];
}

+ (instancetype)errorResponseInfo:(QNResponseInfoErrorType)errorType
                        errorDesc:(NSString *)errorDesc
                            error:(NSError *)error{
    QNResponseInfo *response = [[QNResponseInfo alloc] init];
    response.statusCode = errorType;
    response.msg = [response errorMsgWithErrorCode:errorType];
    response.msgDetail = errorDesc;
    if (error) {
       response.error = error;
    } else {
        NSError *error = [[NSError alloc] initWithDomain:kQNErrorDomain
                                                    code:errorType
                                                userInfo:@{ @"error" : response.msgDetail ?: response.msg ?: @"error" }];
        response.error = error;
    }
    
    return response;
}

+ (instancetype)responseInfoWithHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo
                                        duration:(double)duration {
    if (httpResponseInfo.hasHttpResponse) {
//        return [[QNResponseInfo alloc] initWithStatusCode:(int)httpResponseInfo.statusCode reqId:httpResponseInfo.reqId xlog:httpResponseInfo.xlog xvia:httpResponseInfo.xvia host:httpResponseInfo.host error:httpResponseInfo.error];
        return nil;
    } else {
        return nil;
//        return [[QNResponseInfo alloc] initWithNetError:httpResponseInfo.error host:httpResponseInfo.host];
    }
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
            _statusCode = statusCode;
            _reqId = headers[@"X-Reqid"];
            _xlog = headers[@"X-Log"];
            _xvia = !headers[@"X-Via"] ? (!headers[@"X-Px"] ? headers[@"Fw-Via"] : headers[@"X-Px"]) : headers[@"X-Via"];

            NSMutableDictionary *userInfo = [@{@"errorHost" : host ?: @""} mutableCopy];
            if (statusCode != 200) {
                if (body == nil) {
                    _error = [[NSError alloc] initWithDomain:kQNErrorDomain code:statusCode userInfo:[userInfo copy]];
                } else {
                    NSError *tmp;
                    NSDictionary *responseInfo = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableLeaves error:&tmp];
                    if (tmp != nil) {
                        // 出现错误时，如果信息是非UTF8编码会失败，返回nil
                        NSString *str = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] ?: @"";
                        responseInfo = @{ @"error" : str};
                    }
                    if (responseInfo && [responseInfo isKindOfClass:[NSDictionary class]]) {
                        [userInfo setValuesForKeysWithDictionary:responseInfo];
                    }
                    _error = [[NSError alloc] initWithDomain:kQNErrorDomain code:statusCode userInfo:[userInfo copy]];
                }
            } else if (body == nil || body.length == 0) {
                [userInfo setValue:@"no response json" forKey:@"error"];
                _error = [[NSError alloc] initWithDomain:kQNErrorDomain code:statusCode userInfo:userInfo];
            } else if (error) {
                [userInfo setValue:@"JSON serialization failed" forKey:@"error"];
                _error = [[NSError alloc] initWithDomain:kQNErrorDomain code:statusCode userInfo:userInfo];
            }
        } else if (error) {
            _error = error;
            _statusCode = (int)error.code;
        }
        
        _msg = [self msgWithStatusCode:_statusCode];
    }
    return self;
}

- (instancetype)initWithStatusCode:(int)statusCode
                             reqId:(NSString *)reqId
                              xlog:(NSString *)xlog
                              xvia:(NSString *)xvia
                              host:(NSString *)host
                             error:(NSError *)error {
    if (self = [super init]) {
        _statusCode = statusCode;
        _reqId = reqId;
        _xlog = xlog;
        _xvia = xvia;
        _host = host;
        _error = error;
        _id = [QNUserAgent sharedInstance].id;
        _timeStamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}


- (BOOL)isCancelled {
    return _statusCode == kQNRequestCancelled || _statusCode == -999;
}

- (BOOL)isNotQiniu {
    // reqId is nill means the server is not qiniu
    return (_statusCode >= 200 && _statusCode < 500) && _reqId == nil;
}

- (BOOL)isOK {
    return (_statusCode >= 200 && _statusCode < 300) && _error == nil && _reqId != nil;
}

- (BOOL)couldRetry {
    if (self.isCancelled
        || (_statusCode > 300 && _statusCode < 400)
        || (_statusCode > 400 && _statusCode < 500)
        || _statusCode == 501 || _statusCode == 573
        || _statusCode == 608 || _statusCode == 612 || _statusCode == 614 || _statusCode == 616
        || _statusCode == 619 || _statusCode == 630 || _statusCode == 631 || _statusCode == 640
        || _statusCode == 701
        ||(_statusCode < 0 && _statusCode > -1000)) {
        return NO;
    } else {
        return YES;
    }
//    return (_statusCode >= 500 && _statusCode < 600 && _statusCode != 579) || _statusCode == 996 || _statusCode == 406 || (_statusCode == 200 && _error != nil) || _statusCode < -1000 || self.isNotQiniu;
}

- (BOOL)couldRegionRetry{
    if ([self couldRetry] == NO
        || _statusCode == 400
        || _statusCode == 502 || _statusCode == 503 || _statusCode == 504 || _statusCode == 579 || _statusCode == 599
        || self.isCancelled) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)couldHostRetry{
    if ([self couldRegionRetry] == NO
        || (_statusCode == 502 || _statusCode == 503 || _statusCode == 571)) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)isConnectionBroken {
    return _statusCode == kQNNetworkError || (_statusCode < -1000 && _statusCode != -1003);
}


- (NSString *)msgWithStatusCode:(int)statusCode{
    NSString *msg = nil;
    if (statusCode > 199 && statusCode < 300) {
        msg = @"";
    } else {
        msg = [self errorMsgWithErrorCode:statusCode];
    }
    return msg;
}

- (NSString *)errorMsgWithErrorCode:(int)errorCode{
    NSString *msg = nil;
    switch (errorCode) {
        case QNResponseInfoErrorTypeUnknownError:
            msg = @"unknown_error";
            break;
        case QNResponseInfoErrorTypeNetworkError:
            msg = @"network_error";
            break;
        case QNResponseInfoErrorTypeTimeout:
            msg = @"timeout";
            break;
        case QNResponseInfoErrorTypeUnknownHost:
            msg = @"unknown_host";
            break;
        case QNResponseInfoErrorTypeCannotConnectToHost:
            msg = @"cannot_connect_to_host";
            break;
        case QNResponseInfoErrorTypeConnectionLost:
        case QNResponseInfoErrorTypeBadServerResponse:
            msg = @"transmission_error";
            break;
        case QNResponseInfoErrorTypeProxyError:
            msg = @"proxy_error";
            break;
        case QNResponseInfoErrorTypeSSLError:
        case QNResponseInfoErrorTypeSSLHandShakeError:
            msg = @"ssl_error";
            break;
        case QNResponseInfoErrorTypeCannotDecodeRawData:
        case QNResponseInfoErrorTypeCannotDecodeContentData:
        case QNResponseInfoErrorTypeCannotParseResponse:
            msg = @"response_error";
            break;
        case QNResponseInfoErrorTypeTooManyRedirects:
        case QNResponseInfoErrorTypeRedirectToNonExistentLocation:
            msg = @"malicious_response";
            break;
        case QNResponseInfoErrorTypeUserCanceled:
            msg = @"user_canceled";
            break;
        case QNResponseInfoErrorTypeZeroSizeFile:
            msg = @"zero_size_file";
            break;
        case QNResponseInfoErrorTypeInvalidFile:
            msg = @"invalid_file";
            break;
        case QNResponseInfoErrorTypeInvalidToken:
        case QNResponseInfoErrorTypeInvalidArgs:
            msg = @"invalid_args";
            break;
        case QNResponseInfoErrorTypeUnexpectedSyscallError:
            msg = @"unexpected_syscall_error";
            break;
        case QNResponseInfoErrorTypeLocalIoError:
            msg = @"local_io_error";
            break;
        case QNResponseInfoErrorTypeNetworkSlow:
            msg = @"network_slow";
            break;
        default:
            msg = @"unknown_error";
            break;
    }
    return msg;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@= id: %@, ver: %@, status: %d, requestId: %@, xlog: %@, xvia: %@, host: %@ time: %llu error: %@>", NSStringFromClass([self class]), _id, kQiniuVersion, _statusCode, _reqId, _xlog, _xvia, _host, _timeStamp, _error];
}

@end
