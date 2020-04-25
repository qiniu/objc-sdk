//
//  QNHttpResponseInfo.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNHttpResponseInfo.h"
#import "QNSystemTool.h"
#import "QNUploadInfoReporter.h"
#import "QNUserAgent.h"
#import "QNVersion.h"
#import "QNSessionManager.h"

@interface QNHttpResponseInfo ()
@property (nonatomic, strong) NSDictionary *responseBody;
@end

@implementation QNHttpResponseInfo
+ (QNHttpResponseInfo *)buildResponseInfoHost:(NSString *)host
                                     response:(NSHTTPURLResponse *)response
                                         body:(NSData *)body
                                        error:(NSError *)error
                            sessionStatistics:(QNSessionStatistics *)sessionStatistics {
    return [[[self class] alloc] initWithResponseInfoHost:host response:response body:body error:error sessionStatistics:sessionStatistics];
}

- (instancetype)initWithResponseInfoHost:(NSString *)host
                                response:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error
                       sessionStatistics:(QNSessionStatistics *)sessionStatistics {
    
    self = [super init];
    if (self) {
        
        _proxyConnection = NO;
        _hasHttpResponse = NO;
        _host = host;
        _pid = [QNSystemTool getCurrentProcessID];
        _tid = [QNSystemTool getCurrentThreadID];
        _networkType = [QNSystemTool getCurrentNetworkType];
        _signalStrength = [QNSystemTool getCurrentNetworkSignalStrength];
        _timeStamp = [[NSDate date] timeIntervalSince1970];
        
        if (sessionStatistics) {
            _bytesSent = sessionStatistics.bytesSent;
            _bytesTotal = sessionStatistics.bytesTotal;
            _remoteIp = sessionStatistics.remoteIp;
            _port = sessionStatistics.port;
            _totalElapsedTime = sessionStatistics.totalElapsedTime;
            _dnsElapsedTime = sessionStatistics.dnsElapsedTime;
            _connectElapsedTime = sessionStatistics.connectElapsedTime;
            _tlsConnectElapsedTime = sessionStatistics.tlsConnectElapsedTime;
            _requestElapsedTime = sessionStatistics.requestElapsedTime;
            _waitElapsedTime = sessionStatistics.waitElapsedTime;
            _responseElapsedTime = sessionStatistics.responseElapsedTime;
            _proxyConnection = sessionStatistics.isProxyConnection;
        }
        
        if (response) {
            _hasHttpResponse = YES;
            int statusCode = (int)[response statusCode];
            NSDictionary *headers = [response allHeaderFields];
            _statusCode = statusCode;
            _reqId = headers[@"X-Reqid"];
            _xlog = headers[@"X-Log"];
            _xvia = !headers[@"X-Via"] ? (!headers[@"X-Px"] ? headers[@"Fw-Via"] : headers[@"X-Px"]) : headers[@"X-Via"];

            if (statusCode != 200) {
                if (response.statusCode / 100 == 4) {
                    _errorType = bad_request;
                }  else {
                    _errorType = response_error;
                }
                
                if (body == nil) {
                    _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:nil];
                } else {
                    NSError *tmp;
                    NSDictionary *uInfo = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableLeaves error:&tmp];
                    if (tmp != nil) {
                        // 出现错误时，如果信息是非UTF8编码会失败，返回nil
                        NSString *str = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
                        if (str == nil) {
                            str = @"";
                        }
                        uInfo = @{ @"error" : str };
                    }
                    _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:uInfo];
                }
            } else if (body == nil || body.length == 0) {
                NSDictionary *uInfo = @{ @"error" : @"no response json" };
                _errorType = unknown_error;
                _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:uInfo];
            } else {
                NSError *tmp;
                NSDictionary *responseBody = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableLeaves error:&tmp];
                if (!error) {
                    _responseBody = responseBody;
                } else {
                    NSDictionary *uInfo = @{ @"error" : @"JSON serialization failed" };
                    _errorType = parse_error;
                    _error = [[NSError alloc] initWithDomain:host code:statusCode userInfo:uInfo];
                }
            }
        } else {
            _hasHttpResponse = NO;
            if (self.isProxyConnection) {
                _errorType = proxy_error;
            } else {
                if (error) {
                    _error = error;
                    _statusCode = (int)error.code;
                    _errorDescription = _error.localizedDescription;
                    
                    if (error.code == -1 || error.code == -1009) {
                        _errorType = network_error;
                    } else if (error.code == -1001) {
                        _errorType = network_timeout;
                    } else if (error.code == -1003 || error.code == -1006) {
                        _errorType = unknown_host;
                    } else if (error.code == -1004) {
                        _errorType = cannot_connect_to_host;
                    } else if (error.code == -1005 || error.code == -1011) {
                        _errorType = transmission_error;
                    } else if (error.code > -2001 && error.code < -1199) {
                        _errorType = ssl_error;
                    } else if (error.code == -1007 || error.code == -1010) {
                        _errorType = malicious_response;
                    } else if (error.code == -1015 || error.code == -1016 || error.code == -1017) {
                        _errorType = parse_error;
                    } else if (error.code == -999) {
                        _errorType = user_canceled;
                    } else {
                        _errorType = unknown_error;
                    }
                } else {
                    _errorType = unknown_error;
                }
            }
        }
    }
    return self;
}

- (BOOL)isOK {
    return _statusCode == 200 && _error == nil && _reqId != nil;
}

- (BOOL)couldRetry {
    return (_statusCode >= 500 && _statusCode < 600 && _statusCode != 579) || _statusCode == 996 || _statusCode == 406 || (_statusCode == 200 && _error != nil) || _statusCode < -1000 || self.isNotQiniu;
}

- (BOOL)isNotQiniu {
    return (_statusCode >= 200 && _statusCode < 500) && _reqId == nil;
}

- (NSDictionary *)getResponseBody {
    return self.isOK ? self.responseBody : nil;
}

- (uint64_t)getTimeintervalWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    
    if (!startDate || !endDate) return 0;
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    return interval * 1000;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@= id: %@, ver: %@, status: %d, requestId: %@, xlog: %@, xvia: %@, host: %@ duration: %.3f s time: %llu error: %@>", NSStringFromClass([self class]), [QNUserAgent sharedInstance].id, kQiniuVersion, _statusCode, _reqId, _xlog, _xvia, _host, _totalElapsedTime / 1000.0, _timeStamp, _error];
}

@end
