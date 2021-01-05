//
//  QNSingleFlight.m
//  QiniuSDK
//
//  Created by yangsen on 2021/1/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNSingleFlight.h"

@interface QNSingleFlightTask : NSObject
@property(nonatomic,  copy)QNSingleFlightComplete complete;
@end
@implementation QNSingleFlightTask
@end

@interface QNSingleFlightCall : NSObject
@property(nonatomic, strong)NSMutableArray <QNSingleFlightTask *> *tasks;
@property(nonatomic, strong)id value;
@property(nonatomic, strong)NSError *error;
@end
@implementation QNSingleFlightCall
@end

@interface QNSingleFlight()
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNSingleFlightCall *> *callInfo;
@end
@implementation QNSingleFlight

- (void)perform:(NSString * _Nullable)key
         action:(QNSingleFlightAction _Nonnull)action
       complete:(QNSingleFlightComplete _Nullable)complete {
    if (!action) {
        return;
    }

    QNSingleFlightCall *call = nil;
    NSMutableArray *tasks = nil;
    @synchronized (self) {
        if (!self.callInfo) {
            self.callInfo = [NSMutableDictionary dictionary];
        }
        
        BOOL isFirstTask = false;
        if (key) {
            call = self.callInfo[key];
        }
        
        if (!call) {
            call = [[QNSingleFlightCall alloc] init];
            call.tasks = [NSMutableArray array];
            if (key) {
                self.callInfo[key] = call;
            }
            isFirstTask = true;
        }
        
        @synchronized (call) {
            if (call.value || call.error) {
                if (complete) {
                    complete(call.value, call.error);
                }
                return;
            }
            tasks = call.tasks;
            QNSingleFlightTask *task = [[QNSingleFlightTask alloc] init];
            task.complete = complete;
            [tasks addObject:task];
        }
        
        if (!isFirstTask) {
            return;
        }
    }
    
    kQNWeakSelf;
    action(^(id value, NSError *error){
        kQNStrongSelf;
        
        NSArray *tasksP = nil;
        @synchronized (call) {
            call.value = value;
            call.error = error;
            tasksP = [tasks copy];
        }
        
        for (QNSingleFlightTask *task in tasksP) {
            if (task.complete) {
                task.complete(value, error);
            }
        }
        
        if (key) {
            @synchronized (self) {
                [self.callInfo removeObjectForKey:key];
            }
        }
    });
}

@end
