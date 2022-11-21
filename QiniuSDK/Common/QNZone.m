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

@implementation QNZone

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    return [self getZonesInfoWithToken:token actionType:QNActionTypeNone];
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken * _Nullable)token
                            actionType:(QNActionType)actionType {
    return nil;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    [self preQuery:token actionType:QNActionTypeNone on:ret];
}

- (void)preQuery:(QNUpToken *)token
      actionType:(QNActionType)actionType
              on:(QNPrequeryReturn)ret {
    ret(0, nil, nil);
}

@end
