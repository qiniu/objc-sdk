//
//  QNNetworkCheckManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNNetworkCheckManager.h"
#import "QNUtils.h"
#import "QNNetworkChecker.h"

@interface QNNetworkCheckStatusInfo : NSObject

@property(nonatomic, assign)QNNetworkCheckStatus status;
@property(nonatomic,   copy)NSString *checkedIP;
@property(nonatomic,   copy)NSString *checkedHost;

@end
@implementation QNNetworkCheckStatusInfo
- (NSString *)description{
    NSString *status = @"Unknown_";
    if (self.status > -1 & self.status < 5) {
        status = @[@"Unknown", @"A", @"B", @"C", @"D"][self.status];
    }
    return [NSString stringWithFormat:@"status:%@, checkedIP:%@, checkedHost:%@", status, self.checkedIP, self.checkedHost];
}
@end

@interface QNNetworkCheckManager()<QNNetworkCheckerDelegate>

@property(nonatomic, strong)QNNetworkChecker *networkChecker;
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNNetworkCheckStatusInfo *> *statusInfo;

@end
@implementation QNNetworkCheckManager

+ (instancetype)shared{
    static QNNetworkCheckManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNNetworkCheckManager alloc] init];
        [manager initData];
    });
    return manager;
}

- (void)initData{
    self.statusInfo = [NSMutableDictionary dictionary];
    self.networkChecker = [QNNetworkChecker networkChecker];
    self.networkChecker.delegate = self;
}

- (QNNetworkCheckStatus)getIPNetworkStatus:(NSString *)ip
                                      host:(NSString *)host{
    NSString *ipType = [QNUtils getIpType:ip host:host];
    QNNetworkCheckStatusInfo *statusInfo = self.statusInfo[ipType];
    if (statusInfo) {
        return statusInfo.status;
    } else {
        return QNNetworkCheckStatusUnknown;
    }
}

- (void)preCheckIPNetworkStatus:(NSArray<NSString *> *)ipArray
                           host:(NSString *)host{
    
    for (NSString *ip in ipArray) {
        [self.networkChecker checkIP:ip host:host];
    }
}


//MARKL -- QNNetworkChecker
- (void)checkComplete:(nonnull NSString *)ip host:(nonnull NSString *)host time:(int)time {
    NSString *ipType = [QNUtils getIpType:ip host:host];
    if (ipType == nil && ipType.length == 0) {
        return;
    }

    QNNetworkCheckStatusInfo *statusInfo = [[QNNetworkCheckStatusInfo alloc] init];
    statusInfo.checkedHost = host;
    statusInfo.checkedIP = ip;
    statusInfo.status = [self getNetworkCheckStatus:time];
    self.statusInfo[ipType] = statusInfo;
}

- (QNNetworkCheckStatus)getNetworkCheckStatus:(int)time{
    
    QNNetworkCheckStatus status = QNNetworkCheckStatusUnknown;
    if (time < 1) {
        status = QNNetworkCheckStatusUnknown;
    } else if (time < 150) {
        status = QNNetworkCheckStatusA;
    } else if (time < 500) {
        status = QNNetworkCheckStatusB;
    } else if (time < 2000) {
        status = QNNetworkCheckStatusC;
    } else {
        status = QNNetworkCheckStatusD;
    }
    return status;
}


- (void)setMaxCheckCount:(int)maxCheckCount{
    self.networkChecker.maxCheckCount = maxCheckCount;
}

- (int)maxCheckCount{
    return self.networkChecker.maxCheckCount;
}

@end
