//
//  QNUploadServerNetworkStatus.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNNetworkStatusManager.h"
#import "QNUploadServerNetworkStatus.h"

@implementation QNUploadServerNetworkStatus

+ (QNUploadServer *)getBetterNetworkServer:(QNUploadServer *)serverA serverB:(QNUploadServer *)serverB {
    return [self isServerNetworkBetter:serverA thanServerB:serverB] ? serverA : serverB;
}

+ (BOOL)isServerNetworkBetter:(QNUploadServer *)serverA thanServerB:(QNUploadServer *)serverB {
    if (serverA == nil) {
        return NO;
    } else if (serverB == nil) {
        return YES;
    }
    
    NSString *serverTypeA = [QNNetworkStatusManager getNetworkStatusType:serverA.host ip:serverA.ip];
    NSString *serverTypeB = [QNNetworkStatusManager getNetworkStatusType:serverB.host ip:serverB.ip];
    if (serverTypeA == nil) {
        return NO;
    } else if (serverTypeB == nil) {
        return YES;
    }
    
    QNNetworkStatus *serverStatusA = [kQNNetworkStatusManager getNetworkStatus:serverTypeA];
    QNNetworkStatus *serverStatusB = [kQNNetworkStatusManager getNetworkStatus:serverTypeB];

    return serverStatusB.speed < serverStatusA.speed;
}

@end
