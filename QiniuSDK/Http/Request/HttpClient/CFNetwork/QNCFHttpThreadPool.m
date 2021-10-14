//
//  QNCFHttpThreadPool.m
//  Qiniu
//
//  Created by yangsen on 2021/10/13.
//

#import "QNCFHttpThreadPool.h"
#import "QNTransactionManager.h"

@interface QNCFHttpThread()
@property(nonatomic, assign)BOOL isCompleted;
@property(nonatomic, assign)NSInteger operationCount;
@property(nonatomic, strong)NSDate *deadline;
@end
@implementation QNCFHttpThread
+ (instancetype)thread {
    return [[QNCFHttpThread alloc] init];;
}

- (instancetype)init {
    if (self = [super init]) {
        self.isCompleted = NO;
        self.operationCount = 0;
    }
    return self;
}

- (void)main {
    @autoreleasepool {
        [super main];
        
        while (!self.isCompleted) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    }
}

- (void)cancel {
    self.isCompleted = YES;
}

@end

@interface QNCFHttpThreadPool()
// 单位：秒
@property(nonatomic, assign)NSInteger threadLiveTime;
@property(nonatomic, assign)NSInteger maxOperationPerThread;
@property(nonatomic, strong)NSMutableArray *pool;
@end
@implementation QNCFHttpThreadPool

+ (instancetype)shared {
    static QNCFHttpThreadPool *pool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pool = [[QNCFHttpThreadPool alloc] init];
        pool.threadLiveTime = 60;
        pool.maxOperationPerThread = 6;
        pool.pool = [NSMutableArray array];
        [pool addThreadLiveChecker];
    });
    return pool;
}

- (void)addThreadLiveChecker {
    QNTransaction *transaction = [QNTransaction timeTransaction:@"CFHttpThreadPool" after:0 interval:1 action:^{
        [self checkThreadLive];
    }];
    [kQNTransactionManager addTransaction:transaction];
}

- (void)checkThreadLive {
    @synchronized (self) {
        NSArray *pool = [self.pool copy];
        for (QNCFHttpThread *thread in pool) {
            if (thread.operationCount < 1 && thread.deadline && [thread.deadline timeIntervalSinceNow] < 0) {
                [self.pool removeObject:thread];
                [thread cancel];
            }
        }
    }
}

- (QNCFHttpThread *)getOneThread {
    QNCFHttpThread *thread = nil;
    @synchronized (self) {
        for (QNCFHttpThread *t in self.pool) {
            if (t.operationCount < self.maxOperationPerThread) {
                thread = t;
                break;
            }
        }
        if (thread == nil) {
            thread = [QNCFHttpThread thread];
            thread.name = [NSString stringWithFormat:@"com.qiniu.cfclient.%lu", (unsigned long)self.pool.count];
            [thread start];
            [self.pool addObject:thread];
        }
    }
    return thread;
}

- (void)addOperationCountOfThread:(QNCFHttpThread *)thread {
    if (thread == nil) {
        return;
    }
    @synchronized (self) {
        thread.operationCount += 1;
        thread.deadline = nil;
    }
}

- (void)subtractOperationCountOfThread:(QNCFHttpThread *)thread {
    if (thread == nil) {
        return;
    }
    @synchronized (self) {
        thread.operationCount -= 1;
        if (thread.operationCount < 1) {
            thread.deadline = [NSDate dateWithTimeIntervalSinceNow:self.threadLiveTime];
        }
    }
}

@end
