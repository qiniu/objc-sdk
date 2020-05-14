//
//  QNUploadRegion.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"
#import "QNUploadFixedHostRegion.h"

@interface QNUploadFixedHostRegion()

@end
@implementation QNUploadFixedHostRegion

+ (instancetype)fixedHostRegionWithHosts:(NSArray <NSString *> *)hosts{
    if (!hosts || hosts.count == 0) {
        return nil;
    }
    QNUploadFixedHostRegion *region = [[QNUploadFixedHostRegion alloc] init];
    QNZoneInfo *zoneINfo = [QNZoneInfo zoneInfoWithMainHosts:hosts ioHosts:nil];
    [region setupRegionData:zoneINfo];
    return region;
}

@end
