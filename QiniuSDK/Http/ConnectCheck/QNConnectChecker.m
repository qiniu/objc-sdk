//
//  QNConnectChecker.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2021/1/8.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNDefine.h"
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

+ (BOOL)check {
    __block BOOL isConnected = false;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self check:^(BOOL isConnectedP) {
        isConnected = isConnectedP;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return isConnected;
}

+ (void)check:(void (^)(BOOL isConnected))complete {
    QNSingleFlight *singleFlight = [self singleFlight];
    
    kQNWeakSelf;
    [singleFlight perform:@"connect_check" action:^(QNSingleFlightComplete  _Nonnull singleFlightComplete) {
        kQNStrongSelf;
        
        [self checkAllHosts:^(BOOL isConnected) {
            singleFlightComplete(@(isConnected), nil);
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        if (complete) {
            complete([(NSNumber *)value boolValue]);
        }
    }];
}


+ (void)checkAllHosts:(void (^)(BOOL isConnected))complete {
    
    __block int completeCount = 0;
    __block BOOL isConnected = false;
    kQNWeakSelf;
    NSArray *allHosts = [kQNGlobalConfiguration.connectCheckURLStrings copy];
    for (NSString *host in allHosts) {
        [self checkHost:host complete:^(BOOL isHostConnected) {
            kQNStrongSelf;
            
            @synchronized (self) {
                completeCount += 1;
            }
            if (isHostConnected) {
                isConnected = YES;
            }
            if (completeCount == allHosts.count) {
                complete(isConnected);
            }
        }];
    }
}

+ (void)checkHost:(NSString *)host complete:(void (^)(BOOL isConnected))complete {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.URL = [NSURL URLWithString:host];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 3;
    
    QNUploadSystemClient *client = [[QNUploadSystemClient alloc] init];
    [client request:request connectionProxy:nil progress:nil complete:^(NSURLResponse * response, QNUploadSingleRequestMetrics * metrics, NSData * _Nullable data, NSError * error) {
        if (response && [(NSHTTPURLResponse *)response statusCode] > 99) {
            complete(true);
        } else {
            complete(false);
        }
    }];
}

@end
