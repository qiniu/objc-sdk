//
//  QNNetworkChecker.m
//  QiniuSDK
//
//  Created by yangsen on 2020/7/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNNetworkChecker.h"
#import "QNAsyncSocket.h"

@interface QNNetworkCheckerInfo : NSObject

@property(nonatomic, assign)int count; // 当前检测的次数
@property(nonatomic, assign)long time; // 检测耗费时间
@property(nonatomic,   copy)NSString *ip;
@property(nonatomic,   copy)NSString *host;
@property(nonatomic, strong)NSDate   *startDate; // 当前测试当前批次开始时间

@end
@implementation QNNetworkCheckerInfo
+ (QNNetworkCheckerInfo *)checkerInfo:(NSString *)ip host:(NSString *)host{
    QNNetworkCheckerInfo *info = [[QNNetworkCheckerInfo alloc] init];
    info.count = 0;
    info.ip = ip;
    info.host = host;
    info.startDate = nil;
    return info;
}
- (void)start{
    @synchronized (self) {
        self.count += 1;
        self.startDate = [NSDate date];
    }
}
- (void)stop{
    @synchronized (self) {
        if (self.startDate == nil) {
            return;
        }
        self.time += [[NSDate date] timeIntervalSinceDate:self.startDate]*1000;
        self.startDate = nil;
    }
}
- (BOOL)shouldCheck:(int)count{
    return count > self.count;
}
- (BOOL)isTimeout:(NSDate *)date maxTime:(int)maxTime{
    if (!self.startDate || !date || maxTime < 1) {
        return true;
    }
    int time = [date timeIntervalSinceDate:self.startDate];
    return time >= maxTime;
}
@end

@interface QNNetworkChecker()<QNAsyncSocketDelegate>

@property(nonatomic, strong)NSTimer *timer;

@property(nonatomic, strong)dispatch_queue_t checkQueue;
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNAsyncSocket *> *socketInfoDictionary;
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNNetworkCheckerInfo *> *checkerInfoDictionary;

@end
@implementation QNNetworkChecker

+ (instancetype)networkChecker{
    QNNetworkChecker *checker = [[QNNetworkChecker alloc] init];
    [checker initData];
    return checker;
}

- (void)initData{
    self.maxTime = 9;
    self.maxCheckCount = 2;
    self.socketInfoDictionary = [NSMutableDictionary dictionary];
    self.checkerInfoDictionary = [NSMutableDictionary dictionary];
    self.checkQueue = dispatch_queue_create("com.qiniu.socket", DISPATCH_QUEUE_SERIAL);
}

- (BOOL)checkIP:(NSString *)ip host:(NSString *)host{
    @synchronized (self) {
        if (ip == nil || ip.length == 0 || self.checkerInfoDictionary[ip]) {
            return false;
        }
        QNNetworkCheckerInfo *checkerInfo = [QNNetworkCheckerInfo checkerInfo:ip host:host];
        self.checkerInfoDictionary[ip] = checkerInfo;
    }
    return [self performCheckIFNeeded:ip];
}

- (BOOL)performCheckIFNeeded:(NSString *)ip{
    
    QNNetworkCheckerInfo *checkerInfo = self.checkerInfoDictionary[ip];
    if (checkerInfo == nil) {
        return false;
    }
    
    [checkerInfo stop];
    
    if (![checkerInfo shouldCheck:self.maxCheckCount]) {
        [self ipCheckComplete:ip];
        return false;
    } else {
        return [self connect:ip];
    }
}

- (BOOL)connect:(NSString *)ip{
    QNNetworkCheckerInfo *checkerInfo = self.checkerInfoDictionary[ip];
    if (checkerInfo == nil) {
        return false;
    }
    
    [checkerInfo start];
    NSError *error = nil;
    QNAsyncSocket *socket = [self createSocket];
    NSLog(@"check: ip:%@ host:%@", ip, checkerInfo.host);
    [socket connectToHost:ip onPort:80 error:&error];
    
    if (error) {
        return false;
    } else {
        [self createTimer];
        self.socketInfoDictionary[ip] = socket;
        return true;
    }
}

- (void)disconnect:(NSString *)ip{
    QNAsyncSocket *socket = self.socketInfoDictionary[ip];
    if (socket == nil) {
        return;
    }
    
    [socket disconnect];
}

- (QNAsyncSocket *)createSocket{
    
    QNAsyncSocket *socket = [[QNAsyncSocket alloc] initWithDelegate:self
                                                      delegateQueue:self.checkQueue
                                                        socketQueue:self.checkQueue];
    return socket;
}

- (void)checkTimeout{
    
    NSDate *currentDate = [NSDate date];
    for (NSString *ip in self.checkerInfoDictionary.allKeys) {
        QNNetworkCheckerInfo *checkerInfo = self.checkerInfoDictionary[ip];
        if ([checkerInfo isTimeout:currentDate maxTime:self.maxTime]) {
            [self disconnect:ip];
            [self performCheckIFNeeded:ip];
        }
    }
}

- (void)ipCheckComplete:(NSString *)ip{
    
    if (self.checkerInfoDictionary[ip] == nil) {
        return;
    }
    
    QNNetworkCheckerInfo *checkerInfo = self.checkerInfoDictionary[ip];
    [checkerInfo stop];
    
    [self.checkerInfoDictionary removeObjectForKey:ip];
    
    if ([self.delegate respondsToSelector:@selector(checkComplete:host:time:)]) {
        long time = checkerInfo.time / self.maxCheckCount;
        [self.delegate checkComplete:ip host:checkerInfo.host time:MIN(time, self.maxTime)];
    }

    if (self.checkerInfoDictionary.count == 0) {
        [self invalidateTimer];
        return;
    }
}


//MARK: -- QNAsyncSocketDelegate --
- (void)socket:(QNAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    [sock disconnect];
    [self performCheckIFNeeded:host];
}

- (void)socket:(QNAsyncSocket *)sock didConnectToUrl:(NSURL *)url{
    [sock disconnect];
    [self performCheckIFNeeded:url.host];
}

- (void)socket:(QNAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler{
    if (completionHandler) {
        completionHandler(true);
    }
}

- (void)socketDidDisconnect:(QNAsyncSocket *)sock withError:(nullable NSError *)err{
    for (NSString *ip in self.socketInfoDictionary.allKeys) {
        QNAsyncSocket *socket = self.socketInfoDictionary[ip];
        if (socket == sock) {
            [self.socketInfoDictionary removeObjectForKey:ip];
        }
    }
}

//- (void)socket:(QNAsyncSocket *)sock didAcceptNewSocket:(QNAsyncSocket *)newSocket{}
//- (nullable dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(QNAsyncSocket *)sock{
//    return nil;
//}
//- (void)socket:(QNAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{}
//- (void)socket:(QNAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag{}
//- (void)socket:(QNAsyncSocket *)sock didWriteDataWithTag:(long)tag{}
//- (void)socket:(QNAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag{}
//- (void)socketDidCloseReadStream:(QNAsyncSocket *)sock{}
//- (void)socketDidSecure:(QNAsyncSocket *)sock{}

//MARK: -- timeout
- (void)createTimer{
    @synchronized (self) {
        if (self.timer) {
            return;
        }
    }
    
    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.1
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
    [self checkTimeout];
}


//MARK:-- property
- (void)setMaxTime:(int)maxTime{
    if (maxTime < 1) {
        maxTime = 1;
    } else if (maxTime > 600) {
        maxTime = 600;
    }
    _maxTime = maxTime;
}

@end
