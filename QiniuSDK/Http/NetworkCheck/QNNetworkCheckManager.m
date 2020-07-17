//
//  QNNetworkCheckManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNNetworkCheckManager.h"
#import "QNUtils.h"
#import "QNConfiguration.h"
#import "QNNetworkChecker.h"

@interface QNNetworkCheckStatusInfo : NSObject

@property(nonatomic, assign)QNNetworkCheckStatus status;
@property(nonatomic,   copy)NSString *checkedIP;
@property(nonatomic,   copy)NSString *checkedHost;

@end
@implementation QNNetworkCheckStatusInfo
@end

@interface QNNetworkCheckManager()<QNNetworkCheckerDelegate>

@property(nonatomic, strong)QNNetworkChecker *networkChecker;
@property(nonatomic, strong)NSMutableDictionary <NSString *, NSString *> *checkingIPTypeInfo;
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNNetworkCheckStatusInfo *> *statusInfoDictionary;

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
    self.checkingIPTypeInfo = [NSMutableDictionary dictionary];
    self.statusInfoDictionary = [NSMutableDictionary dictionary];
    self.networkChecker = [QNNetworkChecker networkChecker];
    self.networkChecker.delegate = self;
}

- (QNNetworkCheckStatus)getIPNetworkStatus:(NSString *)ip
                                      host:(NSString *)host{
    NSString *ipType = [QNUtils getIpType:ip host:host];
    QNNetworkCheckStatusInfo *statusInfo = self.statusInfoDictionary[ipType];
    if (statusInfo) {
        return statusInfo.status;
    } else {
        return QNNetworkCheckStatusUnknown;
    }
}

- (void)preCheckIPNetworkStatus:(NSArray<NSString *> *)ipArray
                           host:(NSString *)host{
    
    for (NSString *ip in ipArray) {
        NSString *ipType = [QNUtils getIpType:ip host:host];
        if (ipType && !self.statusInfoDictionary[ipType] && !self.checkingIPTypeInfo[ipType]) {
            self.checkingIPTypeInfo[ipType] = ip;
            [self.networkChecker checkIP:ip host:host];
        }
    }
}

- (void)checkCachedIPListNetworkStatus{
    for (NSString *ipType in self.statusInfoDictionary) {
        QNNetworkCheckStatusInfo *statusInfo = self.statusInfoDictionary[ipType];
        [self.networkChecker checkIP:statusInfo.checkedIP host:statusInfo.checkedHost];
    }
}


//MARKL -- QNNetworkChecker
- (void)checkComplete:(nonnull NSString *)ip host:(nonnull NSString *)host time:(long)time {
    NSString *ipType = [QNUtils getIpType:ip host:host];
    if (ipType == nil && ipType.length == 0) {
        return;
    }

    QNNetworkCheckStatusInfo *statusInfo = [[QNNetworkCheckStatusInfo alloc] init];
    statusInfo.checkedHost = host;
    statusInfo.checkedIP = ip;
    statusInfo.status = [self getNetworkCheckStatus:time];
    self.statusInfoDictionary[ipType] = statusInfo;
    [self.checkingIPTypeInfo removeObjectForKey:ipType];
}

- (QNNetworkCheckStatus)getNetworkCheckStatus:(long)time{
    
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

- (void)setMaxTime:(int)maxTime{
    self.networkChecker.maxTime = maxTime;
}

- (int)maxTime{
    return self.networkChecker.maxTime;
}

@end


@implementation QNTransactionManager(NetworkCheck)
#define kQNCheckCachedIPListNetworkStatusTransactionName @"QNCheckCachedIPListNetworkStatus"
#define kQNCheckSomeIPNetworkStatusTransactionName @"QNCheckSomeIPNetworkStatus"

- (void)addCheckCachedIPListNetworkStatusTransaction{
    
    if ([kQNGlobalConfiguration isCheckOpen] == NO) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int interval = arc4random()%3600 + 1800;
        QNTransaction *transaction = [QNTransaction timeTransaction:kQNCheckCachedIPListNetworkStatusTransactionName
                                                              after:0
                                                           interval:interval
                                                             action:^{
            [kQNNetworkCheckManager checkCachedIPListNetworkStatus];
        }];
        [kQNTransactionManager addTransaction:transaction];
    });
}

- (void)addCheckSomeIPNetworkStatusTransaction:(NSArray <NSString *> *)ipArray
                                          host:(NSString *)host{
    
    [self addCheckCachedIPListNetworkStatusTransaction];
    
    if ([kQNGlobalConfiguration isCheckOpen] == NO) {
        return;
    }
    
    @synchronized (self) {
        NSString *transactionName = [NSString stringWithFormat:@"%@:%@", kQNCheckSomeIPNetworkStatusTransactionName, host];
        QNTransactionManager *transactionManager = [QNTransactionManager shared];
        QNTransaction *transaction = [transactionManager transactionsForName:transactionName].firstObject;
        
        if (!transaction) {
            transaction = [QNTransaction transaction:kQNCheckSomeIPNetworkStatusTransactionName
                                               after:0
                                              action:^{
                [kQNNetworkCheckManager preCheckIPNetworkStatus:ipArray host:host];
            }];
            [kQNTransactionManager addTransaction:transaction];
        }
    }
}

@end
