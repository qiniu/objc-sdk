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
@property(nonatomic,   copy)NSString *ip;
@property(nonatomic,   copy)NSString *host;
@property(nonatomic, strong)NSDate   *startDate;

@end
@implementation QNNetworkCheckerInfo
+ (QNNetworkCheckerInfo *)checkerInfo:(NSString *)ip host:(NSString *)host{
    QNNetworkCheckerInfo *info = [[QNNetworkCheckerInfo alloc] init];
    info.count = 0;
    info.ip = ip;
    info.host = host;
    info.startDate = [NSDate date];
    return info;
}
- (void)increaseCount{
    self.count += 1;
}
- (BOOL)shouldCheck:(int)count{
    return count > self.count;
}
@end

@interface QNNetworkChecker()<QNAsyncSocketDelegate>

@property(nonatomic, strong)dispatch_queue_t checkQueue;
@property(nonatomic, strong)NSMutableArray *socketArray;
@property(nonatomic, strong)NSMutableDictionary <NSString *, QNNetworkCheckerInfo *> *checkerInfoDictionary;

@end
@implementation QNNetworkChecker

+ (instancetype)networkChecker{
    QNNetworkChecker *checker = [[QNNetworkChecker alloc] init];
    [checker initData];
    return checker;
}

- (void)initData{
    self.maxCheckCount = 2;
    self.socketArray = [NSMutableArray array];
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
    return [self checkCanConnectAndPerform:ip];
}

- (BOOL)checkCanConnectAndPerform:(NSString *)ip{
    QNNetworkCheckerInfo *checkerInfo = self.checkerInfoDictionary[ip];
    if (checkerInfo == nil) {
        return false;
    }
    
    if (![checkerInfo shouldCheck:self.maxCheckCount]) {
        [self checkComplete:ip];
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
    
    [checkerInfo increaseCount];
    NSError *error = nil;
    QNAsyncSocket *socket = [self createSocket];
    [socket connectToHost:ip onPort:80 error:&error];
    [self.socketArray addObject:socket];
    
    NSLog(@"== Checker connect: ip:%@ host:%@ err:%@", ip, checkerInfo.host, error);
    
    return error == nil;
}

- (QNAsyncSocket *)createSocket{
    
    QNAsyncSocket *socket = [[QNAsyncSocket alloc] initWithDelegate:self
                                                      delegateQueue:self.checkQueue
                                                        socketQueue:self.checkQueue];
    return socket;
}

- (void)checkComplete:(NSString *)ip{
    if (self.checkerInfoDictionary[ip] == nil) {
        return;
    }
    
    
    QNNetworkCheckerInfo *checkerInfo = self.checkerInfoDictionary[ip];
    [self.checkerInfoDictionary removeObjectForKey:ip];
    
    if ([self.delegate respondsToSelector:@selector(checkComplete:host:time:)]) {
        int time = [[NSDate date] timeIntervalSinceDate:checkerInfo.startDate] * 500;
        [self.delegate checkComplete:ip host:checkerInfo.host time:time];
        NSLog(@"== Checker complete: ip:%@ host:%@ time:%d", ip, checkerInfo.host, time);
    }

}

//MARK: -- QNAsyncSocketDelegate --
- (void)socket:(QNAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    [sock disconnect];
    [self checkCanConnectAndPerform:host];
}

- (void)socket:(QNAsyncSocket *)sock didConnectToUrl:(NSURL *)url{
    [sock disconnect];
    [self checkCanConnectAndPerform:url.host];
}

- (void)socket:(QNAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler{
    if (completionHandler) {
        completionHandler(true);
    }
}

- (void)socketDidDisconnect:(QNAsyncSocket *)sock withError:(nullable NSError *)err{
//    [self.socketArray removeObject:sock];
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

@end
