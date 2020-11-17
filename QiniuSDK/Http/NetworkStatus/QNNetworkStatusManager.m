//
//  QNNetworkStatusManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNNetworkStatusManager.h"

@implementation QNNetworkStatus
- (instancetype)init{
    if (self = [super init]) {
        _speed = 200;
        _supportHTTP3 = NO;
    }
    return self;
}
@end


@interface QNNetworkStatusManager()

@property(nonatomic, strong)NSMutableDictionary<NSString *, QNNetworkStatus *> *networkStatusInfo;

@end
@implementation QNNetworkStatusManager

+ (instancetype)sharedInstance{
    static QNNetworkStatusManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNNetworkStatusManager alloc] init];
        manager.networkStatusInfo = [NSMutableDictionary dictionary];
    });
    return manager;
}

- (QNNetworkStatus *)getNetworkStatus:(NSString *)type{
    if (type == nil && type.length > 0) {
        return nil;
    }
    QNNetworkStatus *status = self.networkStatusInfo[type];
    if (status == nil){
        status = [[QNNetworkStatus alloc] init];
    }
    return status;
}

- (void)updateNetworkStatus:(NSString *)type
                      speed:(int)speed{
    if (type == nil && type.length > 0) {
        return;
    }
    
    QNNetworkStatus *status = self.networkStatusInfo[type];
    if (status == nil) {
        status = [[QNNetworkStatus alloc] init];
        self.networkStatusInfo[type] = status;
    }
    status.speed = speed;
}

- (void)updateNetworkStatus:(NSString *)type
               supportHTTP3:(BOOL)supportHTTP3{
    if (type == nil && type.length > 0) {
        return;
    }
    
    QNNetworkStatus *status = self.networkStatusInfo[type];
    if (status == nil) {
        status = [[QNNetworkStatus alloc] init];
        self.networkStatusInfo[type] = status;
    }
    status.supportHTTP3 = supportHTTP3;
}

@end
