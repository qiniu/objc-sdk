//
//  QNUtils.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/3/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>


@implementation QNUtils

+ (NSTimeInterval)currentTimestamp{
    return [[NSDate date] timeIntervalSince1970] * 1000;
}

@end
