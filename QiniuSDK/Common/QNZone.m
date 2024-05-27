//
//  QNZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZone.h"
#import "QNUpToken.h"
#import "QNZoneInfo.h"
#import "QNConfiguration.h"
#import "QNResponseInfo.h"

@implementation QNZone

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    return nil;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    ret(0, nil, nil);
}

- (void)query:(QNConfiguration * _Nullable)config token:(QNUpToken * _Nullable)token on:(QNQueryReturn _Nullable)ret {
    ret([QNResponseInfo responseInfoWithSDKInteriorError:@"impl query"], nil, nil);
}

@end
