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

+ (BOOL)isConnected:(NSHTTPURLResponse *)response {
    return response.statusCode > 99;
}

+ (NSHTTPURLResponse *)check {
    __block NSHTTPURLResponse *response = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self check:^(NSHTTPURLResponse *responseP) {
        response = responseP;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return response;
}

+ (void)check:(void (^)(NSHTTPURLResponse *))complete {
    QNSingleFlight *singleFlight = [self singleFlight];
    
    kQNWeakSelf;
    [singleFlight perform:@"connect_check" action:^(QNSingleFlightComplete  _Nonnull singleFlightComplete) {
        kQNStrongSelf;
        
        [self checkAllHosts:^(NSHTTPURLResponse *response) {
            singleFlightComplete(response, nil);
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        if (complete) {
            complete(value);
        }
    }];
}


+ (void)checkAllHosts:(void (^)(NSHTTPURLResponse *response))complete {
    
    __block int completeCount = 0;
    __block BOOL isCompleted = false;
    __block BOOL isConnected = false;
    kQNWeakSelf;
    NSArray *allHosts = [kQNGlobalConfiguration.connectCheckURLStrings copy];
    for (NSString *host in allHosts) {
        [self checkHost:host complete:^(NSHTTPURLResponse *response) {
            kQNStrongSelf;
            
            BOOL isHostConnected = [self isConnected:response];
            @synchronized (self) {
                completeCount += 1;
            }
            if (isHostConnected) {
                isConnected = YES;
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
                complete(response);
            } else {
                QNLogInfo(@"== check all hosts not completed totalCount:%d completeCount:%d", allHosts.count, completeCount);
            }
        }];
    }
}

+ (void)checkHost:(NSString *)host complete:(void (^)(NSHTTPURLResponse *response))complete {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.URL = [NSURL URLWithString:host];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = kQNGlobalConfiguration.connectCheckTimeout;
    
    QNUploadSystemClient *client = [[QNUploadSystemClient alloc] init];
    [client request:request connectionProxy:nil progress:nil complete:^(NSURLResponse *response, QNUploadSingleRequestMetrics * metrics, NSData * _Nullable data, NSError * error) {
        QNLogInfo(@"== checkHost:%@ responseInfo:%@", host, response);
        complete((NSHTTPURLResponse *)response);
    }];
}

@end
