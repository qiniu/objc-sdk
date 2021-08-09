//
//  QNConnectChecker.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2021/1/8.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNLogUtil.h"
#import "QNConfiguration.h"
#import "QNSingleFlight.h"
#import "QNConnectChecker.h"
#import "QNUploadSystemClient.h"

@interface QNConnectChecker()

@end
@implementation QNConnectChecker

+ (QNSingleFlight *)singleFlight {
    static QNSingleFlight *singleFlight = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleFlight = [[QNSingleFlight alloc] init];
    });
    return singleFlight;
}

+ (dispatch_queue_t)checkQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.qiniu.NetworkCheckQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

+ (BOOL)isConnected:(QNUploadSingleRequestMetrics *)metrics {
    return metrics && ((NSHTTPURLResponse *)metrics.response).statusCode > 99;
}

+ (QNUploadSingleRequestMetrics *)check {
    __block QNUploadSingleRequestMetrics *metrics = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self check:^(QNUploadSingleRequestMetrics *metricsP) {
        metrics = metricsP;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return metrics;
}

+ (void)check:(void (^)(QNUploadSingleRequestMetrics *))complete {
    QNSingleFlight *singleFlight = [self singleFlight];
    
    kQNWeakSelf;
    [singleFlight perform:@"connect_check" action:^(QNSingleFlightComplete  _Nonnull singleFlightComplete) {
        kQNStrongSelf;
        
        [self checkAllHosts:^(QNUploadSingleRequestMetrics *metrics) {
            singleFlightComplete(metrics, nil);
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        if (complete) {
            complete(value);
        }
    }];
}


+ (void)checkAllHosts:(void (^)(QNUploadSingleRequestMetrics *metrics))complete {
    
    __block int completeCount = 0;
    __block BOOL isCompleted = false;
    kQNWeakSelf;
    NSArray *allHosts = [kQNGlobalConfiguration.connectCheckURLStrings copy];
    for (NSString *host in allHosts) {
        [self checkHost:host complete:^(QNUploadSingleRequestMetrics *metrics) {
            kQNStrongSelf;
            
            BOOL isHostConnected = [self isConnected:metrics];
            @synchronized (self) {
                completeCount += 1;
            }
            if (isHostConnected || completeCount == allHosts.count) {
                @synchronized (self) {
                    if (isCompleted) {
                        QNLogInfo(@"== check all hosts has completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
                        return;
                    } else {
                        QNLogInfo(@"== check all hosts completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
                        isCompleted = true;
                    }
                }
                complete(metrics);
            } else {
                QNLogInfo(@"== check all hosts not completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
            }
        }];
    }
}

+ (void)checkHost:(NSString *)host complete:(void (^)(QNUploadSingleRequestMetrics *metrics))complete {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.URL = [NSURL URLWithString:host];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = kQNGlobalConfiguration.connectCheckTimeout;
    
    __block BOOL hasCallback = false;
    
    QNUploadSingleRequestMetrics *timeoutMetric = [QNUploadSingleRequestMetrics emptyMetrics];
    [timeoutMetric start];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * kQNGlobalConfiguration.connectCheckTimeout), [self checkQueue], ^{
        @synchronized (self) {
            if (hasCallback) {
                return;
            }
            hasCallback = true;
        }
        [timeoutMetric end];
        timeoutMetric.error = [NSError errorWithDomain:@"com.qiniu.NetworkCheck" code:NSURLErrorTimedOut userInfo:nil];
        complete(nil);
    });
    
    QNUploadSystemClient *client = [[QNUploadSystemClient alloc] init];
    [client request:request connectionProxy:nil progress:nil complete:^(NSURLResponse *response, QNUploadSingleRequestMetrics * metrics, NSData * _Nullable data, NSError * error) {
        @synchronized (self) {
            if (hasCallback) {
                return;
            }
            hasCallback = true;
        }
        QNLogInfo(@"== checkHost:%@ responseInfo:%@", host, response);
        complete(metrics);
    }];
}

@end
