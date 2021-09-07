//
//  QNUtils.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/3/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#include <pthread.h>
#import "QNVersion.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@implementation QNUtils

+ (NSString *)sdkVersion{
    return kQiniuVersion;
}

+ (NSString *)sdkLanguage{
    return @"Object-C";
}

+ (int64_t)getCurrentProcessID {
    return [[NSProcessInfo processInfo] processIdentifier];
}

+ (int64_t)getCurrentThreadID {
    __uint64_t threadId = 0;
    if (pthread_threadid_np(0, &threadId)) {
           threadId = pthread_mach_thread_np(pthread_self());
    }
    return threadId;
}

+ (NSString *)systemName{
    NSString *name = nil;
    #if __IPHONE_OS_VERSION_MIN_REQUIRED
        name = [[UIDevice currentDevice] model];
    #else
        name = @"Mac OS X";
    #endif
    return name;
}

+ (NSString *)systemVersion{
    NSString *version = nil;
    #if __IPHONE_OS_VERSION_MIN_REQUIRED
        version = [[UIDevice currentDevice] systemVersion];
    #else
        version = [[NSProcessInfo processInfo] operatingSystemVersionString];
    #endif
    return version;
}

/// 信号格数
+ (NSNumber *)getCurrentSignalStrength{
    NSNumber *strength = nil;
    return strength;
}

/// 网络类型
+ (NSString *)getCurrentNetworkType{
    NSString *type = nil;
    return type;
}

+ (NSTimeInterval)currentTimestamp{
    return [[NSDate date] timeIntervalSince1970] * 1000;
}


+ (NSString *)sdkDocumentDirectory{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"/qiniu"];
}

+ (NSString *)sdkCacheDirectory{
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"/qiniu"];
}

+ (NSString *)formEscape:(NSString *)string{
    NSString *ret = string;
    ret = [ret stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    ret = [ret stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return ret;
}

+ (NSNumber *)dateDuration:(NSDate *)startDate endDate:(NSDate *)endDate {
    if (startDate && endDate) {
        double time = [endDate timeIntervalSinceDate:startDate] * 1000;
        return @(time);
    } else {
        return nil;
    }
}

+ (NSNumber *)calculateSpeed:(long long)bytes totalTime:(long long)totalTime {
    if (bytes < 0 || totalTime == 0) {
        return nil;
    }
    long long speed = bytes * 1000 / totalTime;
    return @(speed);
}

+ (NSString *)getIpType:(NSString *)ip host:(NSString *)host{
    
    NSString *type = host;
    if (!ip || ip.length == 0) {
        return type;
    }
    if ([ip rangeOfString:@":"].location != NSNotFound) {
        type = [self getIPV6StringType:ip host:host];
    } else if ([ip rangeOfString:@"."].location != NSNotFound){
        type = [self getIPV4StringType:ip host:host];
    }
    return type;
}

+ (NSString *)getIPV4StringType:(NSString *)ipv4String host:(NSString *)host{
    NSString *type = nil;
    NSArray *ipNumberStrings = [ipv4String componentsSeparatedByString:@"."];
    if (ipNumberStrings.count == 4) {
        NSInteger firstNumber = [ipNumberStrings.firstObject integerValue];
        NSInteger secondNumber = [ipNumberStrings[1] integerValue];
        type = [NSString stringWithFormat:@"%ld-%ld",(long)firstNumber, (long)secondNumber];
    }
    type = [NSString stringWithFormat:@"%@-%@", host ?:@"", type];
    return type;
}

+ (NSString *)getIPV6StringType:(NSString *)ipv6String host:(NSString *)host{
    NSArray *ipNumberStrings = [ipv6String componentsSeparatedByString:@":"];
    NSMutableArray *ipNumberStringsReal = [@[@"0000", @"0000", @"0000", @"0000",
                                            @"0000", @"0000", @"0000", @"0000"] mutableCopy];
    NSArray *suppleStrings = @[@"0000", @"000", @"00", @"0", @""];
    NSInteger i = 0;
    while (i < ipNumberStrings.count) {
        NSString *ipNumberString = ipNumberStrings[i];
        if (ipNumberString.length > 0) {
            ipNumberString = [NSString stringWithFormat:@"%@%@", suppleStrings[ipNumberString.length], ipNumberString];
            ipNumberStringsReal[i] = ipNumberString;
        } else {
            break;
        }
        i++;
    }
    
    NSInteger j = ipNumberStrings.count - 1;
    NSInteger indexReal = ipNumberStringsReal.count - 1;
    while (i < j) {
        NSString *ipNumberString = ipNumberStrings[j];
        if (ipNumberString.length > 0) {
            ipNumberString = [NSString stringWithFormat:@"%@%@", suppleStrings[ipNumberString.length], ipNumberString];
            ipNumberStringsReal[indexReal] = ipNumberString;
        } else {
            break;
        }
        j--;
        indexReal--;
    }
    NSString *numberInfo = [[ipNumberStringsReal subarrayWithRange:NSMakeRange(0, 4)] componentsJoinedByString:@"-"];
    return [NSString stringWithFormat:@"%@-%@-%@", host ?:@"", @"ipv6", numberInfo];
}

@end

