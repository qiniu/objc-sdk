//
//  QNNetworkStatusManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNCache.h"
#import "QNAsyncRun.h"
#import "QNFileRecorder.h"
#import "QNRecorderDelegate.h"
#import "QNNetworkStatusManager.h"

@interface QNNetworkStatus()<QNCacheObject>
@property(nonatomic, assign)int speed;
@end
@implementation QNNetworkStatus
- (instancetype)init{
    if (self = [super init]) {
        _speed = 200;
    }
    return self;
}

- (nonnull id<QNCacheObject>)initWithDictionary:(nonnull NSDictionary *)dictionary {
    QNNetworkStatus *status = [[QNNetworkStatus alloc] init];
    status.speed = [dictionary[@"speed"] intValue];
    return status;
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

@property(nonatomic, strong)QNCache *cache;

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
    QNCacheOption *option = [[QNCacheOption alloc] init];
    option.version = @"v1.0.2";
    option.flushCount = 10;
    self.cache = [QNCache cache:[QNNetworkStatus class] option:option];
}

+ (NSString *)getNetworkStatusType:(NSString *)host
                                ip:(NSString *)ip {
    return [QNUtils getIpType:ip host:host];
}

- (QNNetworkStatus *)getNetworkStatus:(NSString *)type{
    if (type == nil || type.length == 0) {
        return nil;
    }
    return [self.cache cacheForKey:type];
}

- (void)updateNetworkStatus:(NSString *)type speed:(int)speed{
    if (type == nil || type.length == 0) {
        return;
    }
    
    QNNetworkStatus *status = [[QNNetworkStatus alloc] init];
    status.speed = speed;
    [self.cache cache:status forKey:type atomically:false];
}

@end
