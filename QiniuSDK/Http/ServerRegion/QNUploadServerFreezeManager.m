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
@property(nonatomic,   copy)NSString *type;
@property(nonatomic, strong)NSDate *freezeDate;
@end
@implementation QNUploadServerFreezeItem
+ (instancetype)item:(NSString *)type{
    QNUploadServerFreezeItem *item = [[QNUploadServerFreezeItem alloc] init];
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

- (instancetype)init{
    if (self = [super init]) {
        _freezeInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)isTypeFrozen:(NSString * _Nullable)type {
    if (!type || type.length == 0) {
        return true;
    }
    
    BOOL isFrozen = true;
    QNUploadServerFreezeItem *item = nil;
    @synchronized (self) {
        item = self.freezeInfo[type];
    }
    
    if (!item || ![item isFrozenByDate:[NSDate date]]) {
        isFrozen = false;
    }
    
    return isFrozen;
}

- (void)freezeType:(NSString * _Nullable)type frozenTime:(NSInteger)frozenTime {
    if (!type || type.length == 0) {
        return;
    }
    
    QNUploadServerFreezeItem *item = nil;
    @synchronized (self) {
        item = self.freezeInfo[type];
        if (!item) {
            item = [QNUploadServerFreezeItem item:type];
            self.freezeInfo[type] = item;
        }
    }
    
    [item freeze:frozenTime];
}

- (void)unfreezeType:(NSString * _Nullable)type {
    if (!type || type.length == 0) {
        return;
    }
    
    @synchronized (self) {
        [self.freezeInfo removeObjectForKey:type];
    }
}

- (NSString *)getItemInfoKey:(NSString *)host type:(NSString *)type{
    return [NSString stringWithFormat:@"%@:%@", host ?: @"none", type ?: @"none"];
}

@end
