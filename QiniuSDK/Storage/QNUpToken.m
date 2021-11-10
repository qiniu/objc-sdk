//
//  QNUpToken.m
//  QiniuSDK
//
//  Created by bailong on 15/6/7.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNUrlSafeBase64.h"
#import "QNUpToken.h"

#define kQNPolicyKeyScope @"scope"
#define kQNPolicyKeyDeadline @"deadline"
#define kQNPolicyKeyReturnUrl @"returnUrl"
@interface QNUpToken ()

- (instancetype)init:(NSDictionary *)policy token:(NSString *)token;

@end

@implementation QNUpToken

+ (instancetype)getInvalidToken {
    QNUpToken *token = [[QNUpToken alloc] init];
    token->_deadline = -1;
    return token;
}

- (instancetype)init:(NSDictionary *)policy token:(NSString *)token {
    if (self = [super init]) {
        _token = token;
        _access = [self getAccess];
        _bucket = [self getBucket:policy];
        _deadline = [policy[kQNPolicyKeyDeadline] longValue];
        _hasReturnUrl = (policy[kQNPolicyKeyReturnUrl] != nil);
    }

    return self;
}

- (NSString *)getAccess {

    NSRange range = [_token rangeOfString:@":" options:NSCaseInsensitiveSearch];
    return [_token substringToIndex:range.location];
}

- (NSString *)getBucket:(NSDictionary *)info {

    NSString *scope = [info objectForKey:kQNPolicyKeyScope];
    if (!scope || [scope isKindOfClass:[NSNull class]]) {
        return @"";
    }

    NSRange range = [scope rangeOfString:@":"];
    if (range.location == NSNotFound) {
        return scope;
    }
    return [scope substringToIndex:range.location];
}

+ (instancetype)parse:(NSString *)token {
    if (token == nil) {
        return nil;
    }
    NSArray *array = [token componentsSeparatedByString:@":"];
    if (array == nil || array.count != 3) {
        return nil;
    }

    NSData *data = [QNUrlSafeBase64 decodeString:array[2]];
    if (!data) {
        return nil;
    }
    
    NSError *tmp = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&tmp];
    if (tmp != nil || dict[kQNPolicyKeyScope] == nil || dict[kQNPolicyKeyDeadline] == nil) {
        return nil;
    }
    return [[QNUpToken alloc] init:dict token:token];
}

- (NSString *)index {
    return [NSString stringWithFormat:@"%@:%@", _access, _bucket];
}

- (BOOL)isValid {
    return _access && _access.length > 0 && _bucket && _bucket.length > 0;
}

- (BOOL)isValidForDuration:(long)duration {
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:duration];
    return [self isValidBeforeDate:date];
}

- (BOOL)isValidBeforeDate:(NSDate *)date {
    if (date == nil) {
        return NO;
    }
    return [date timeIntervalSince1970] < self.deadline;
}

@end
