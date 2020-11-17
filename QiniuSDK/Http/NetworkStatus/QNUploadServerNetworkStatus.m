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

+ (BOOL)isServerSupportHTTP3:(QNUploadServer *)server{
    if (server == nil) {
        return false;
    }
    
    NSString *serverType = [QNUtils getIpType:server.ip host:server.host];
    if (serverType == nil) {
        return false;
    }
    
    QNNetworkStatus *serverStatus = [kQNNetworkStatusManager getNetworkStatus:serverType];
    return serverStatus.supportHTTP3;
}

+ (QNUploadServer *)getBetterNetworkServer:(QNUploadServer *)serverA
                                   serverB:(QNUploadServer *)serverB{
    if (serverA == nil) {
        return serverB;
    } else if (serverB == nil) {
        return serverA;
    }
    
    NSString *serverTypeA = [QNUtils getIpType:serverA.ip host:serverA.host];
    NSString *serverTypeB = [QNUtils getIpType:serverA.ip host:serverA.host];
    if (serverTypeA == nil) {
        return serverB;
    } else if (serverTypeB == nil) {
        return serverA;
    }
    
    QNNetworkStatus *serverStatusA = [kQNNetworkStatusManager getNetworkStatus:serverTypeA];
    QNNetworkStatus *serverStatusB = [kQNNetworkStatusManager getNetworkStatus:serverTypeB];

    return serverStatusB.speed < serverStatusA.speed ? serverA : serverB;
}

@end
