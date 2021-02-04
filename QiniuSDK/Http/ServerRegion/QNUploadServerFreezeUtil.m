//
//  QNUploadServerFreezeUtil.m
//  QiniuSDK
//
//  Created by yangsen on 2021/2/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNUploadServerFreezeUtil.h"

@implementation QNUploadServerFreezeUtil

+ (QNUploadServerFreezeManager *)sharedHttp2Freezer {
    static QNUploadServerFreezeManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNUploadServerFreezeManager alloc] init];
    });
    return manager;
}

+ (QNUploadServerFreezeManager *)sharedHttp3Freezer {
    static QNUploadServerFreezeManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNUploadServerFreezeManager alloc] init];
    });
    return manager;
}

+ (BOOL)isType:(NSString *)type frozenByFreezeManagers:(NSArray <QNUploadServerFreezeManager *> *)freezeManagerList{
    if (!type || type.length == 0) {
        return YES;
    }
    if (!freezeManagerList || freezeManagerList.count == 0) {
        return NO;
    }
    
    BOOL isFrozen = NO;
    for (QNUploadServerFreezeManager *freezeManager in freezeManagerList) {
        isFrozen = [freezeManager isTypeFrozen:type];
        if (isFrozen) {
            break;
        }
    }
    return isFrozen;
}

+ (NSString *)getFrozenType:(NSString *)host ip:(NSString *)ip {
    NSString *ipType = [QNUtils getIpType:ip host:host];
    return [NSString stringWithFormat:@"%@-%@", host, ipType];
}

@end
