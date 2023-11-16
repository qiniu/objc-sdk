//
//  QNUrlUtils.m
//  QiniuSDK
//
//  Created by yangsen on 2023/11/16.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import "QNUrlUtils.h"

@implementation QNUrlUtils

+ (NSString *)setHostScheme:(NSString *)host useHttps:(BOOL)useHttps {
    if (host == nil || host.length == 0) {
        return nil;
    }

    if ([host hasPrefix:@"http://"] || [host hasPrefix:@"https://"]) {
        return host;
    }

    return [NSString stringWithFormat:@"%@%@", (useHttps ? @"https://" : @"http://"), host];
}

@end
