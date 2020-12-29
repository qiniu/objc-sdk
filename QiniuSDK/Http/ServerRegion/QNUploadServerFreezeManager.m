//
//  QNUploadServerFreezeManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/6/2.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"
#import "QNUploadServerFreezeManager.h"

@interface QNUploadServerFreezeItem : NSObject
@property(nonatomic,   copy)NSString *host;
@property(nonatomic,   copy)NSString *type;
@property(nonatomic, strong)NSDate *freezeDate;
@end
@implementation QNUploadServerFreezeItem
+ (instancetype)item:(NSString *)host type:(NSString *)type{
    QNUploadServerFreezeItem *item = [[QNUploadServerFreezeItem alloc] init];
    item.host = host;
    item.type = type;
    return item;
}
- (BOOL)isFrozenByDate:(NSDate *)date{
    BOOL isFrozen = YES;
    @synchronized (self) {
        if (!self.freezeDate || [self.freezeDate timeIntervalSinceDate:date] < 0){
            isFrozen = NO;
        }
    }
    return isFrozen;
}
- (void)freeze:(NSInteger)frozenTime{
    @synchronized (self) {
        self.freezeDate = [NSDate dateWithTimeIntervalSinceNow:frozenTime];
    }
}
@end

@interface QNUploadServerFreezeManager()

@property(nonatomic, strong)NSMutableDictionary *freezeInfo;

@end
@implementation QNUploadServerFreezeManager

+ (instancetype)shared{
    static QNUploadServerFreezeManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNUploadServerFreezeManager alloc] init];
    });
    return manager;
}

- (instancetype)init{
    if (self = [super init]) {
        _freezeInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)isFrozenHost:(NSString *)host type:(NSString *)type{
    if (!host || host.length == 0) {
        return true;
    }
    BOOL isFrozen = true;
    NSString *infoKey = [self getItemInfoKey:host type:type];
    
    QNUploadServerFreezeItem *item = nil;
    @synchronized (self) {
        item = self.freezeInfo[infoKey];
    }
    if (!item || ![item isFrozenByDate:[NSDate date]]) {
        isFrozen = false;
    }
    return isFrozen;
}

- (void)freezeHost:(NSString *)host
              type:(NSString * _Nullable)type
        frozenTime:(NSInteger)frozenTime{
    if (!host || host.length == 0) {
        return;
    }
    NSString *infoKey = [self getItemInfoKey:host type:type];
    QNUploadServerFreezeItem *item = nil;
    @synchronized (self) {
        item = self.freezeInfo[infoKey];
        if (!item) {
            item = [QNUploadServerFreezeItem item:host type:type];
            self.freezeInfo[infoKey] = item;
        }
    }
    [item freeze:frozenTime];
}

- (void)unfreezeHost:(NSString *)host type:(NSString *)type {
    if (!host || host.length == 0) {
        return;
    }
    NSString *infoKey = [self getItemInfoKey:host type:type];
    if (infoKey != nil){
        @synchronized (self) {
            [self.freezeInfo removeObjectForKey:infoKey];
        }
    }
}

- (NSString *)getItemInfoKey:(NSString *)host type:(NSString *)type{
    return [NSString stringWithFormat:@"%@:%@", host ?: @"none", type ?: @"none"];
}

@end
