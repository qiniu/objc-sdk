//
//  QNNetworkStatusManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNAsyncRun.h"
#import "QNFileRecorder.h"
#import "QNRecorderDelegate.h"
#import "QNNetworkStatusManager.h"

@interface QNNetworkStatus()
@property(nonatomic, assign)int speed;
@end
@implementation QNNetworkStatus
- (instancetype)init{
    if (self = [super init]) {
        _speed = 200;
    }
    return self;
}
- (NSDictionary *)toDictionary{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:@(self.speed) forKey:@"speed"];
    return dictionary;
}
+ (QNNetworkStatus *)statusFromDictionary:(NSDictionary *)dictionary{
    QNNetworkStatus *status = [[QNNetworkStatus alloc] init];
    status.speed = [dictionary[@"speed"] intValue];
    return status;
}
@end


@interface QNNetworkStatusManager()

@property(nonatomic, assign)BOOL isHandlingNetworkInfoOfDisk;
@property(nonatomic, strong)id<QNRecorderDelegate> recorder;
@property(nonatomic, strong)NSMutableDictionary<NSString *, QNNetworkStatus *> *networkStatusInfo;

@end
@implementation QNNetworkStatusManager

+ (instancetype)sharedInstance{
    static QNNetworkStatusManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNNetworkStatusManager alloc] init];
        [manager initData];
    });
    return manager;
}

- (void)initData{
    self.isHandlingNetworkInfoOfDisk = NO;
    self.networkStatusInfo = [NSMutableDictionary dictionary];
    self.recorder = [QNFileRecorder fileRecorderWithFolder:[[QNUtils sdkCacheDirectory] stringByAppendingString:@"/NetworkStatus"] error:nil];
    [self asyncRecordNetworkStatusInfo];
}

+ (NSString *)getNetworkStatusType:(NSString *)host
                                ip:(NSString *)ip {
    return [QNUtils getIpType:ip host:host];
}

- (QNNetworkStatus *)getNetworkStatus:(NSString *)type{
    if (type == nil || type.length == 0) {
        return nil;
    }
    QNNetworkStatus *status = nil;
    @synchronized (self) {
        status = self.networkStatusInfo[type];
    }
    if (status == nil) {
        status = [[QNNetworkStatus alloc] init];
    }
    return status;
}

- (void)updateNetworkStatus:(NSString *)type speed:(int)speed{
    if (type == nil || type.length == 0) {
        return;
    }
    
    @synchronized (self) {
        QNNetworkStatus *status = self.networkStatusInfo[type];
        if (status == nil) {
            status = [[QNNetworkStatus alloc] init];
            self.networkStatusInfo[type] = status;
        }
        status.speed = speed;
    }
    
    [self asyncRecordNetworkStatusInfo];
}


// ----- status 持久化
#define kNetworkStatusDiskKey @"NetworkStatus:v1.0.0"
- (void)asyncRecordNetworkStatusInfo{
    @synchronized (self) {
        if (self.isHandlingNetworkInfoOfDisk) {
            return;
        }
        self.isHandlingNetworkInfoOfDisk = YES;
    }
    QNAsyncRun(^{
        [self recordNetworkStatusInfo];
        self.isHandlingNetworkInfoOfDisk = NO;
    });
}
- (void)asyncRecoverNetworkStatusFromDisk{
    @synchronized (self) {
        if (self.isHandlingNetworkInfoOfDisk) {
            return;
        }
        self.isHandlingNetworkInfoOfDisk = YES;
    }
    QNAsyncRun(^{
        [self recoverNetworkStatusFromDisk];
        self.isHandlingNetworkInfoOfDisk = NO;
    });
}
- (void)recordNetworkStatusInfo{
    if (self.recorder == nil || self.networkStatusInfo == nil) {
        return;
    }
    NSMutableDictionary *statusInfo = [NSMutableDictionary dictionary];
    for (NSString *key in self.networkStatusInfo.allKeys) {
        NSDictionary *statusDictionary = [self.networkStatusInfo[key] toDictionary];
        if (statusDictionary) {
            [statusInfo setObject:statusDictionary forKey:key];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:statusInfo options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [self.recorder set:kNetworkStatusDiskKey data:data];
    }
}

- (void)recoverNetworkStatusFromDisk{
    if (self.recorder == nil) {
        return;
    }

    NSData *data = [self.recorder get:kNetworkStatusDiskKey];
    if (data == nil) {
        return;
    }

    NSError *error = nil;
    NSDictionary *statusInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![statusInfo isKindOfClass:[NSDictionary class]]) {
        [self.recorder del:kNetworkStatusDiskKey];
        return;
    }

    NSMutableDictionary *networkStatusInfo = [NSMutableDictionary dictionary];
    for (NSString *key in statusInfo.allKeys) {
        NSDictionary *value = statusInfo[key];
        QNNetworkStatus *status = [QNNetworkStatus statusFromDictionary:value];
        if (status) {
            [networkStatusInfo setObject:status forKey:key];
        }
    }
    
    [self.networkStatusInfo setValuesForKeysWithDictionary:networkStatusInfo];
}

@end
