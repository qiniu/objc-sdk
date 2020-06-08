//
//  NSURLRequest+QNRequest.m
//  AppTest
//
//  Created by yangsen on 2020/4/8.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <objc/runtime.h>
#import "NSURLRequest+QNRequest.h"


@implementation NSURLRequest(QNRequest)

#define kQNURLReuestHostKey @"Host"
#define kQNURLReuestIdentifierKey @"QNURLReuestIdentifier"
- (BOOL)qn_isQiNiuRequest{
    if (self.qn_identifier && self.qn_domain) {
        return YES;
    } else {
        return NO;
    }
}

- (NSString *)qn_identifier{
    return self.allHTTPHeaderFields[kQNURLReuestIdentifierKey];
}

- (NSString *)qn_domain{
    NSString *host = self.allHTTPHeaderFields[kQNURLReuestHostKey];
    if (host == nil) {
        host = self.URL.host;
    }
    return host;
}

- (NSDictionary *)qn_allHTTPHeaderFields{
    NSDictionary *headerFields = [self.allHTTPHeaderFields copy];
    NSMutableDictionary *headerFieldsNew = [NSMutableDictionary dictionary];
    for (NSString *key in headerFields) {
        if (![key isEqualToString:kQNURLReuestIdentifierKey]) {
            [headerFieldsNew setObject:headerFields[key] forKey:key];
        }
    }
    return [headerFieldsNew copy];
}

+ (instancetype)qn_requestWithURL:(NSURL *)url{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:url.host forHTTPHeaderField:kQNURLReuestHostKey];
    return request;
}


- (NSData *)qn_getHttpBody{
    
    if (self.HTTPBody || ![self.HTTPMethod isEqualToString:@"POST"]) {
        return self.HTTPBody;
    }
    
    NSInteger maxLength = 1024;
    uint8_t d[maxLength];
    
    NSInputStream *stream = self.HTTPBodyStream;
    NSMutableData *data = [NSMutableData data];
    
    [stream open];
    
    BOOL end = NO;
    
    while (!end) {
        NSInteger bytesRead = [stream read:d maxLength:maxLength];
        if (bytesRead == 0) {
            end = YES;
        } else if (bytesRead == -1){
            end = YES;
        } else if (stream.streamError == nil){
            [data appendBytes:(void *)d length:bytesRead];
       }
    }
    [stream close];
    return [data copy];
}

- (BOOL)qn_isHttps{
    if ([self.URL.absoluteString containsString:@"https://"]) {
        return YES;
    } else {
        return NO;
    }
}
@end


@implementation NSMutableURLRequest(QNRequest)

- (void)setQn_domain:(NSString *)qn_domain{
    if (qn_domain) {
        [self addValue:qn_domain forHTTPHeaderField:kQNURLReuestHostKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kQNURLReuestHostKey];
    }
    
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *identifier = [NSString stringWithFormat:@"%lf%@", timestamp, qn_domain];
    [self setQn_identifier:identifier];
}

- (void)setQn_identifier:(NSString *)qn_identifier{
    if (qn_identifier) {
        [self addValue:qn_identifier forHTTPHeaderField:kQNURLReuestIdentifierKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kQNURLReuestIdentifierKey];
    }
}

@end
