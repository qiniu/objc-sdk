//
//  QNTransactionManager.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNTransactionManager.h"

//MARK: -- 事务对象
typedef NS_ENUM(NSInteger, QNTransactionType){
    QNTransactionTypeNormal, // 普通类型事务，事务体仅会执行一次
    QNTransactionTypeTime, // 定时事务，事务体会定时执行
};

@interface QNTransaction()
// 事务类型
@property(nonatomic, assign)QNTransactionType type;
// 定时任务执行时间间隔
@property(nonatomic, assign)NSInteger interval;
// 事务延后时间 单位：秒
@property(nonatomic, assign)NSInteger after;
// 事务执行时间 与事务管理者定时器时间相关联
@property(nonatomic, assign)long long actionTime;

// 事务名称
@property(nonatomic,  copy)NSString *name;
// 事务执行体
@property(nonatomic,  copy)void(^action)(void);
// 下一个需要处理的事务
@property(nonatomic, strong, nullable)QNTransaction *nextTransaction;

@end
@implementation QNTransaction

+ (instancetype)transaction:(NSString *)name
                      after:(NSInteger)after
                     action:(void (^)(void))action{
    QNTransaction *transaction = [[QNTransaction alloc] init];
    transaction.type = QNTransactionTypeNormal;
    transaction.after = after;
    transaction.name = name;
    transaction.action = action;
    return transaction;
}

+ (instancetype)timeTransaction:(NSString *)name
                          after:(NSInteger)after
                       interval:(NSInteger)interval
                         action:(void (^)(void))action{
    QNTransaction *transaction = [[QNTransaction alloc] init];
    transaction.type = QNTransactionTypeTime;
    transaction.after = after;
    transaction.name = name;
    transaction.interval = interval;
    transaction.action = action;
    return transaction;
}

- (BOOL)shouldAction:(long long)time{
    if (time < self.actionTime) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)maybeCompleted:(long long)time{
    if (time >= self.actionTime && self.type == QNTransactionTypeNormal) {
        return YES;
    } else {
        return NO;
    }
}

- (void)handlerAction:(long long)time{
    if (![self shouldAction:time]) {
        return;
    }
    if (self.action) {
        self.action();
    }
    if (self.type == QNTransactionTypeNormal) {
        self.actionTime = 0;
    } else if(self.type == QNTransactionTypeTime) {
        self.actionTime = time + self.interval;
    }
}

@end


//MARK: -- 事务链表
@interface QNTransactionList : NSObject

@property(nonatomic, strong)QNTransaction *header;

@end
@implementation QNTransactionList

- (BOOL)isEmpty{
    if (self.header == nil) {
        return YES;
    } else {
        return NO;
    }
}

- (NSArray <QNTransaction *> *)transcationsForName:(NSString *)name{
    NSMutableArray *transcations = [NSMutableArray array];
    [self enumerate:^(QNTransaction *transaction, BOOL * _Nonnull stop) {
        if ([transaction.name isEqualToString:name]) {
            [transcations addObject:transaction];
        }
    }];
    return [transcations copy];
}

- (void)enumerate:(void(^)(QNTransaction *transaction, BOOL * _Nonnull stop))handler {
    if (!handler) {
        return;
    }
    BOOL isStop = NO;
    QNTransaction *transaction = self.header;
    while (transaction && !isStop) {
        handler(transaction, &isStop);
        transaction = transaction.nextTransaction;
    }
}

- (void)add:(QNTransaction *)transaction{
    
    @synchronized (self) {
        QNTransaction *transactionP = self.header;
        while (transactionP.nextTransaction) {
            transactionP = transactionP.nextTransaction;
        }
        
        if (transactionP) {
            transactionP.nextTransaction = transaction;
        } else {
            self.header = transaction;
        }
    }
}

- (void)remove:(QNTransaction *)transaction{
    
    @synchronized (self) {
        QNTransaction *transactionP = self.header;
        QNTransaction *transactionLast = nil;
        while (transactionP) {
            if (transactionP == transaction) {
                if (transactionLast) {
                    transactionLast.nextTransaction = transactionP.nextTransaction;
                } else {
                    self.header = transactionP.nextTransaction;
                }
                break;
            }
            transactionLast = transactionP;
            transactionP = transactionP.nextTransaction;
        }
    }
}

- (BOOL)has:(QNTransaction *)transaction{
    @synchronized (self) {
        __block BOOL has = NO;
        [self enumerate:^(QNTransaction *transactionP, BOOL * _Nonnull stop) {
            if (transaction == transactionP) {
                has = YES;
                *stop = YES;
            }
        }];
        return has;
    }
}

- (void)removeAll{
    @synchronized (self) {
        self.header = nil;
    }
}

@end


//MARK: -- 事务管理者
@interface QNTransactionManager()
// 事务处理线程
@property(nonatomic, strong)NSThread *thread;
// 事务链表
@property(nonatomic, strong)QNTransactionList *transactionList;

// 定时器执行次数
@property(nonatomic, assign)long long time;
// 事务定时器
@property(nonatomic, strong)NSTimer *timer;

@end
@implementation QNTransactionManager

+ (instancetype)shared{
    static QNTransactionManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QNTransactionManager alloc] init];
    });
    return manager;
}
- (instancetype)init{
    if (self = [super init]) {
        _time = 0;
        _transactionList = [[QNTransactionList alloc] init];
    }
    return self;
}

- (NSArray <QNTransaction *> *)transcationsForName:(NSString *)name{
    return [self.transactionList transcationsForName:name];
}

- (BOOL)existTranscationsForName:(NSString *)name{
    NSArray *transactionList = [self transcationsForName:name];
    if (transactionList && transactionList.count > 0) {
        return YES;
    } else {
        return NO;
    }
}

- (void)addTransaction:(QNTransaction *)transaction{

    transaction.actionTime = self.time + transaction.after;
    [self.transactionList add:transaction];
    
    [self createThread];
}

- (void)removeTransaction:(QNTransaction *)transaction{
    
    BOOL canDestroyResource = NO;

    [self.transactionList remove:transaction];
    if ([self.transactionList isEmpty]) {
        canDestroyResource = YES;
    }
//    
//    if (canDestroyResource) {
//        [self destroyResource];
//    }
}

- (void)preformTransaction:(QNTransaction *)transaction{
    if (!transaction) {
        return;
    }
    @synchronized (self) {
        if (![self.transactionList has:transaction]) {
            [self.transactionList add:transaction];
        }
        transaction.actionTime = self.time;
    }
}

/// 销毁资源
- (void)destroyResource{

    @synchronized (self) {
        [self invalidateTimer];
        [self.thread cancel];
        self.thread = nil;
        [self.transactionList removeAll];
    }
}


//MARK: -- handle transaction action
- (void)handleAllTransaction{
    
    [self.transactionList enumerate:^(QNTransaction *transaction, BOOL * _Nonnull stop) {
        [self handleTransaction:transaction];
        if ([transaction maybeCompleted:self.time]) {
            [self removeTransaction:transaction];
        }
    }];
}

- (void)handleTransaction:(QNTransaction *)transaction{
    [transaction handlerAction:self.time];
}

//MARK: -- thread
- (void)createThread{
    @synchronized (self) {
        if (self.thread == nil) {
            __weak typeof(self) weakSelf = self;
            self.thread = [[NSThread alloc] initWithTarget:weakSelf
                                                  selector:@selector(threadHandler)
                                                     object:nil];
            self.thread.name = @"com.qiniu.transcation";
            [self.thread start];
        }
    }
}

- (void)threadHandler{

    @autoreleasepool {
        if (self.timer == nil) {
            [self createTimer];
        }
        NSThread *thread = [NSThread currentThread];
        while (thread && !thread.isCancelled) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }
}

//MARK: -- timer
- (void)createTimer{
    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:1
                                             target:weakSelf
                                           selector:@selector(timerAction)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer
                                 forMode:NSDefaultRunLoopMode];
    
    [self timerAction];
    _timer = timer;
}

- (void)invalidateTimer{
    [self.timer invalidate];
    self.timer = nil;
}

- (void)timerAction{
    self.time += 1;
    [self handleAllTransaction];
}

@end
