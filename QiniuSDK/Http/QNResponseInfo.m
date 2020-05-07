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

/**
   https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Constants/index.html#//apple_ref/doc/constant_group/URL_Loading_System_Error_Codes

   NSURLErrorUnknown = -1,
   NSURLErrorCancelled = -999,
   NSURLErrorBadURL = -1000,
   NSURLErrorTimedOut = -1001,
   NSURLErrorUnsupportedURL = -1002,
   NSURLErrorCannotFindHost = -1003,
   NSURLErrorCannotConnectToHost = -1004,
   NSURLErrorDataLengthExceedsMaximum = -1103,
   NSURLErrorNetworkConnectionLost = -1005,
   NSURLErrorDNSLookupFailed = -1006,
   NSURLErrorHTTPTooManyRedirects = -1007,
   NSURLErrorResourceUnavailable = -1008,
   NSURLErrorNotConnectedToInternet = -1009,
   NSURLErrorRedirectToNonExistentLocation = -1010,
   NSURLErrorBadServerResponse = -1011,
   NSURLErrorUserCancelledAuthentication = -1012,
   NSURLErrorUserAuthenticationRequired = -1013,
   NSURLErrorZeroByteResource = -1014,
   NSURLErrorCannotDecodeRawData = -1015,
   NSURLErrorCannotDecodeContentData = -1016,
   NSURLErrorCannotParseResponse = -1017,
   NSURLErrorInternationalRoamingOff = -1018,
   NSURLErrorCallIsActive = -1019,
   NSURLErrorDataNotAllowed = -1020,
   NSURLErrorRequestBodyStreamExhausted = -1021,
   NSURLErrorFileDoesNotExist = -1100,
   NSURLErrorFileIsDirectory = -1101,
   NSURLErrorNoPermissionsToReadFile = -1102,
   NSURLErrorSecureConnectionFailed = -1200,
   NSURLErrorServerCertificateHasBadDate = -1201,
   NSURLErrorServerCertificateUntrusted = -1202,
   NSURLErrorServerCertificateHasUnknownRoot = -1203,
   NSURLErrorServerCertificateNotYetValid = -1204,
   NSURLErrorClientCertificateRejected = -1205,
   NSURLErrorClientCertificateRequired = -1206,
   NSURLErrorCannotLoadFromNetwork = -2000,
   NSURLErrorCannotCreateFile = -3000,
   NSURLErrorCannotOpenFile = -3001,
   NSURLErrorCannotCloseFile = -3002,
   NSURLErrorCannotWriteToFile = -3003,
   NSURLErrorCannotRemoveFile = -3004,
   NSURLErrorCannotMoveFile = -3005,
   NSURLErrorDownloadDecodingFailedMidStream = -3006,
   NSURLErrorDownloadDecodingFailedToComplete = -3007
 */

static NSString *domain = @"qiniu.com";

@interface QNResponseInfo ()

@end

@implementation QNResponseInfo

+ (instancetype)cancelWithDuration:(double)duration {
    return [[QNResponseInfo alloc] initWithStatus:kQNRequestCancelled errorDescription:@"cancelled by user" duration:duration];
}

+ (instancetype)responseInfoWithInvalidArgument:(NSString *)text duration:(double)duration {
    return [[QNResponseInfo alloc] initWithStatus:kQNInvalidArgument errorDescription:text duration:duration];
}

+ (instancetype)responseInfoWithInvalidToken:(NSString *)text duration:(double)duration {
    return [[QNResponseInfo alloc] initWithStatus:kQNInvalidToken errorDescription:text duration:duration];
}

+ (instancetype)responseInfoWithFileError:(NSError *)error duration:(double)duration {
    return [[QNResponseInfo alloc] initWithStatus:kQNFileError error:error host:nil duration:duration];
}

+ (instancetype)responseInfoOfZeroData:(NSString *)path duration:(double)duration {
    NSString *desc;
    if (path == nil) {
        desc = @"data size is 0";
    } else {
        desc = [[NSString alloc] initWithFormat:@"file %@ size is 0", path];
    }
    return [[QNResponseInfo alloc] initWithStatus:kQNZeroDataSize errorDescription:desc duration:duration];
}

+ (instancetype)responseInfoWithHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo duration:(double)duration {
    if (httpResponseInfo.hasHttpResponse) {
        return [[QNResponseInfo alloc] initWithStatusCode:(int)httpResponseInfo.statusCode reqId:httpResponseInfo.reqId xlog:httpResponseInfo.xlog xvia:httpResponseInfo.xvia host:httpResponseInfo.host error:httpResponseInfo.error duration:duration];
    } else {
        return [[QNResponseInfo alloc] initWithNetError:httpResponseInfo.error host:httpResponseInfo.host duration:duration];
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

            if (statusCode != 200) {
                if (body == nil) {
                    _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:nil];
                } else {
                    NSError *tmp;
                    NSDictionary *uInfo = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableLeaves error:&tmp];
                    if (tmp != nil) {
                        // 出现错误时，如果信息是非UTF8编码会失败，返回nil
                        NSString *str = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] ?: @"";
                        uInfo = @{ @"error" : str};
                    }
                    _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:uInfo];
                }
            } else if (body == nil || body.length == 0) {
                NSDictionary *uInfo = @{ @"error" : @"no response json" };
                _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:uInfo];
            } else if (error) {
                NSDictionary *uInfo = @{ @"error" : @"JSON serialization failed" };
                _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:uInfo];
            }
        } else if (error) {
            _error = error;
            _statusCode = (int)error.code;
        }
    }
    return self;
}

- (instancetype)initWithStatus:(int)status
                         errorDescription:(NSString *)text
                      duration:(double)duration {
    NSError *error = [[NSError alloc] initWithDomain:domain code:status userInfo:@{ @"error" : text }];
    return [self initWithStatus:status error:error host:nil duration:duration];
}

- (instancetype)initWithStatus:(int)status
                         error:(NSError *)error
                          host:(NSString *)host
                      duration:(double)duration {
    if (self = [super init]) {
        _statusCode = status;
        _error = error;
        _host = host;
        _duration = duration;
        _id = [QNUserAgent sharedInstance].id;
        _timeStamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (instancetype)initWithNetError:(NSError *)error
                            host:(NSString *)host
                        duration:(double)duration {
    int code = kQNNetworkError;
    if (error != nil) {
        code = (int)error.code;
    }
    return [[QNResponseInfo alloc] initWithStatus:code error:error host:host duration:duration];
}

- (instancetype)initWithStatusCode:(int)statusCode
                             reqId:(NSString *)reqId
                              xlog:(NSString *)xlog
                              xvia:(NSString *)xvia
                              host:(NSString *)host
                             error:(NSError *)error
                          duration:(double)duration  {
    if (self = [super init]) {
        _statusCode = statusCode;
        _reqId = reqId;
        _xlog = xlog;
        _xvia = xvia;
        _host = host;
        _error = error;
        _duration = duration;
        _id = [QNUserAgent sharedInstance].id;
        _timeStamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@= id: %@, ver: %@, status: %d, requestId: %@, xlog: %@, xvia: %@, host: %@ duration: %.3f s time: %llu error: %@>", NSStringFromClass([self class]), _id, kQiniuVersion, _statusCode, _reqId, _xlog, _xvia, _host, _duration, _timeStamp, _error];
}

- (BOOL)isCancelled {
    return _statusCode == kQNRequestCancelled || _statusCode == -999;
}

- (BOOL)isNotQiniu {
    // reqId is nill means the server is not qiniu
    return (_statusCode >= 200 && _statusCode < 500) && _reqId == nil;
}

- (BOOL)isOK {
    return _statusCode == 200 && _error == nil && _reqId != nil;
}

- (BOOL)couldRetry {
    return (_statusCode >= 500 && _statusCode < 600 && _statusCode != 579) || _statusCode == 996 || _statusCode == 406 || (_statusCode == 200 && _error != nil) || _statusCode < -1000 || self.isNotQiniu;
}

- (BOOL)isConnectionBroken {
    return _statusCode == kQNNetworkError || (_statusCode < -1000 && _statusCode != -1003);
}

@end
