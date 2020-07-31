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

#define kQNURLRequestHostKey @"Host"
#define kQNURLRequestIPKey @"QNURLRequestIP"
#define kQNURLRequestIdentifierKey @"QNURLRequestIdentifier"
- (BOOL)qn_isQiNiuRequest{
    if (self.qn_identifier && self.qn_domain) {
        return YES;
    } else {
        return NO;
    }
}

- (NSString *)qn_identifier{
    return self.allHTTPHeaderFields[kQNURLRequestIdentifierKey];
}

- (NSString *)qn_domain{
    NSString *host = self.allHTTPHeaderFields[kQNURLRequestHostKey];
    if (host == nil) {
        host = self.URL.host;
    }
    return host;
}

- (NSString *)qn_ip{
    return self.allHTTPHeaderFields[kQNURLRequestIPKey];
}

- (NSDictionary *)qn_allHTTPHeaderFields{
    NSDictionary *headerFields = [self.allHTTPHeaderFields copy];
    NSMutableDictionary *headerFieldsNew = [NSMutableDictionary dictionary];
    for (NSString *key in headerFields) {
        if (![key isEqualToString:kQNURLRequestIdentifierKey]) {
            [headerFieldsNew setObject:headerFields[key] forKey:key];
        }
    }
    return [headerFieldsNew copy];
}

+ (instancetype)qn_requestWithURL:(NSURL *)url{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:url.host forHTTPHeaderField:kQNURLRequestHostKey];
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
    if ([self.URL.absoluteString rangeOfString:@"https://"].location != NSNotFound) {
        return YES;
    } else {
        return NO;
    }
}
@end


@implementation NSMutableURLRequest(QNRequest)

- (void)setQn_domain:(NSString *)qn_domain{
    if (qn_domain) {
        [self addValue:qn_domain forHTTPHeaderField:kQNURLRequestHostKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kQNURLRequestHostKey];
    }

    NSString *identifier = [NSString stringWithFormat:@"%p-%@", &self, qn_domain];
    [self setQn_identifier:identifier];
}

- (void)setQn_ip:(NSString *)qn_ip{
    if (qn_ip) {
        [self addValue:qn_ip forHTTPHeaderField:kQNURLRequestIPKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kQNURLRequestIPKey];
    }
}

- (void)setQn_identifier:(NSString *)qn_identifier{
    if (qn_identifier) {
        [self addValue:qn_identifier forHTTPHeaderField:kQNURLRequestIdentifierKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kQNURLRequestIdentifierKey];
    }
}

@end
