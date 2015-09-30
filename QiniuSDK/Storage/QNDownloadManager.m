//
//  QNDownloadManager.m
//  QiniuSDK
//
//  Created by ltz on 9/10/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <arpa/inet.h>

#import "QNAsyncRun.h"
#import "HappyDNS.h"
#import "AFNetworking.h"
#import "QNConfiguration.h"
#import "QNDownloadManager.h"

void setStat(NSMutableDictionary *dic, id key, id value) {
    if (value == nil) {
        return;
    }
    [dic setObject:value forKey:key];
}

@implementation QNDownloadManager

- (instancetype) init {
    
    return [self initWithConfiguration:nil sessionConfiguration:nil statsManager:nil];
}

- (instancetype) initWithConfiguration:(QNConfiguration *)config
                  sessionConfiguration:(AFURLSessionManager *)manager
                          statsManager:(QNStats *)statsManager {
    
    self = [super init];
    if (config == nil) {
        config = [QNConfiguration build: ^(QNConfigurationBuilder *builder) {}];
    }
    _config = config;
    
    if (manager == nil) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    }
    _manager = manager;
    
    // TODO: isGatherStats
    if (statsManager == nil) {
        statsManager = [[QNStats alloc] initWithConfiguration:config];
    }
    _statsManager = statsManager;
    
    return self;
}

- (NSData *) dataWithContentsOfURL:(NSString *) url {
    return nil;
}

- (NSURLRequest *) newRequest:(NSURLRequest *)request
                        stats:(NSMutableDictionary *)stats {
    
    NSString *host = request.URL.host;
    setStat(stats, @"domain", host);
    
    if (![QNDownloadManager isValidIPAddress:host]) {
        
        
        NSDate *s0 = [NSDate date];
        // 查询DNS
        NSArray *ips = [_config.dns queryWithDomain:[[QNDomain alloc] init:host hostsFirst:NO hasCname:YES maxTtl:1000]];
        
        // 记录DNS查询时间
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:s0];
        [stats setObject:[NSNumber numberWithInt:(int)(interval*1000)] forKey:@"dt"];
        if ([ips count] == 0) {
            // error;
            // TODO
            return nil;
        }
        
        // 记录实际请求的IP
//        [stats setObject:ips[0] forKey:@"ip"];
        setStat(stats, @"ip", ips[0]);
        NSRange range = [request.URL.absoluteString rangeOfString:request.URL.host];
        NSString *newURL = [request.URL.absoluteString stringByReplacingCharactersInRange:range
                                                                               withString:ips[0]];
        
        NSMutableURLRequest *newRequest = [request mutableCopy];
        newRequest.URL = [[NSURL alloc] initWithString:newURL];
        [newRequest setValue:host forHTTPHeaderField:@"Host"];
        request = newRequest;
        
    } else {
        setStat(stats, @"ip", host);

    }
    
    return request;
}

- (QNSessionDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request
                                              progress:(NSProgress *__autoreleasing *)progress
                                           destination:(NSURL * (^__strong)(NSURL *__strong, NSURLResponse *__strong))destination
                                     completionHandler:(void (^__strong)(NSURLResponse *__strong, NSURL *__strong, NSError *__strong))completionHandler {

    NSMutableDictionary *stats = [[NSMutableDictionary alloc] init];
    
    NSURLSessionTask* (^taskGener)(void) = ^{
        
        NSURLRequest *newRequest = [self newRequest:request stats:stats];
        if (newRequest == nil) {
            newRequest = request;
        }
        
        NSURLSessionDownloadTask *realTask =  [_manager downloadTaskWithRequest:newRequest
                                                                       progress:progress destination:destination
                                                              completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                                                                  if (![stats objectForKey:@"invalid"]) {
                                                                      // update stats
                                                                      
                                                                      // 记录本地出口IP
                                                                      setStat(stats, @"sip", _statsManager.sip);

                                                                      
                                                                      // costed time
                                                                      long long now = (long long)([[NSDate date] timeIntervalSince1970]* 1000000000);
                                                                      long long st = [[stats valueForKey:@"st"] longLongValue];
                                                                      NSNumber *td = [NSNumber numberWithLongLong:(now - st)/1000000];
                                                                      setStat(stats, @"td", td);
                                                                      
                                                                      // size
                                                                      if (response != nil) {
                                                                          NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                                          [stats setObject:[NSNumber numberWithInteger:[httpResponse statusCode]] forKey:@"code"];
                                                                          
                                                                          // ok 用于设定访问是否成功（未写到文档里面
                                                                          [stats setObject:@"1" forKey:@"ok"];
                                                                          
                                                                          if ([httpResponse statusCode]/100 == 2) {
                                                                              if (httpResponse.expectedContentLength != NSURLResponseUnknownLength) {
                                                                                  [stats setObject:[NSNumber numberWithLongLong:httpResponse.expectedContentLength] forKey:@"bd"];
                                                                              } else {
                                                                                  NSNumber *fileSizeValue = nil;
                                                                                  
                                                                                  [filePath getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:nil];
                                                                                  if (fileSizeValue) {
                                                                                      [stats setObject:fileSizeValue forKey:@"bd"];
                                                                                  }
                                                                              }
                                                                          }
                                                                          
                                                                      } else {
                                                                          [stats setObject:@"0" forKey:@"ok"];
                                                                      }
                                                                      
                                                                      NSLog(@"stats: %@", stats);
                                                                      [_statsManager addStatics:stats];
                                                                  } else {
                                                                  }
                                                                  completionHandler(response, filePath, error);
                                                              }];
        if (_statsManager.reachabilityStatus == ReachableViaWiFi) {
            [stats setObject:@"wifi" forKey:@"net"];
        } else if (_statsManager.reachabilityStatus == ReachableViaWWAN) {
            [stats setObject:@"wan" forKey:@"net"];
        }
        return realTask;
    };
    
    return [[QNSessionDownloadTask alloc] initWithTaskGener:taskGener stats:stats];
    
}

+ (BOOL) isValidIPAddress:(NSString *)ip {
    const char *utf8 = [ip UTF8String];
    if (utf8 == nil) {
        return true;
    }
    int success;
    
    struct in_addr dst;
    success = inet_pton(AF_INET, utf8, &dst);
    if (success != 1) {
        struct in6_addr dst6;
        success = inet_pton(AF_INET6, utf8, &dst6);
    }
    
    return success == 1;
}

@end


@implementation QNSessionDownloadTask

- (instancetype) initWithTaskGener:(NSURLSessionTask* (^)(void))taskGener
                             stats:(NSMutableDictionary *)stats {
    self = [super init];
    
    _stats = stats;
    _taskGener = taskGener;
    _realTask = nil;
    _lock = [[NSLock alloc] init];
    
    _taskStat = TaskNotStarted;
    _expectedAction = TaskCreate;
    
    return self;
}

- (void) cancel {
    [_lock lock];
    NSLog(@"cancel, %u", _taskStat);
    if (_taskStat != TaskNormal) {
        _expectedAction = TaskCancel;
        [_lock unlock];
        return;
    }
    [_lock unlock];
    
    [_realTask cancel];
}
- (void) resume {
    
    [_lock lock];

    if (_taskStat == TaskFailed || _taskStat == TaskGenerating) {
        // 如果是 之前运行过resume失败，或者是resume正在产生task，这时候不执行就可以；
        [_lock unlock];
        return;
    }
    
    if (_taskStat == TaskNormal) {
        [_lock unlock];
        // 曾经suspend过的记录有问题，不上报
        [_stats setObject:[NSNumber numberWithBool:true] forKey:@"invalid"];
        [_realTask resume];
        return;
    }
    
    // TaskNotStarted
    _taskStat = TaskGenerating;
    [_lock unlock];
    
    
    QNAsyncRun(^{
        
        // 产生task的过程中会需要去查询DNS，所以用异步操作
        _realTask = _taskGener();
        _taskGener = nil; // 可以提前释放资源，这个东西只会被调用一次

        [_lock lock];
        
        // 首先设置产生task的状态： 失败或者成功
        if (_realTask == nil) {
            _taskStat = TaskFailed;
            [_lock unlock];
            return;
        }
        _taskStat = TaskNormal;
        
        // task 产生成功之后，需要判断在产生期间外部是否设置了动作
        if (_expectedAction == TaskCancel) {
            [_lock unlock];
            [_realTask cancel];
            return;
        }
        if (_expectedAction == TaskSuspend) {
            [_lock unlock];
            return;
        }

        // 首次启动的时候记录启动时间，中间如果有暂停或者取消，那么本次的记录值可以作废，因为开始时间已经不对了
        // 不过实际上可以通过progress拿到suspend或者cancel时下载好的部分数据，后面再做
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [_stats setObject: [NSNumber numberWithLongLong:(long long)(now*1000000000)] forKey:@"st"];
        
        [_lock unlock];

        [_realTask resume];
    });

}
- (void) suspend {
    
    [_lock lock];
    
    if (_taskStat != TaskNormal) {
        _expectedAction = TaskSuspend;
        [_lock unlock];
        return;
    }
    [_lock unlock];
    
    [_realTask suspend];
}


@end

