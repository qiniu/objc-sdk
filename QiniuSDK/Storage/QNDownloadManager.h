//
//  QNDownloadManager.h
//  QiniuSDK
//
//  Created by ltz on 9/10/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QNConfiguration.h"
#import "QNStats.h"

typedef enum {
	TaskFailed = 0,
	TaskNotStarted,
	TaskGenerating,
	TaskNormal
} TaskStat;

typedef enum {
	TaskCreate = 0,
	TaskResume,
	TaskSuspend,
	TaskCancel
} TaskAction;

@interface QNSessionDownloadTask : NSObject

@property (nonatomic) NSURLSessionTask *realTask;
@property (nonatomic) NSMutableDictionary *stats;
@property (nonatomic) NSLock *lock;
@property TaskStat taskStat;
@property TaskAction expectedAction;

@property (nonatomic, copy) NSURLSessionTask* (^taskGener)(void);

- (instancetype) initWithTaskGener:(NSURLSessionTask* (^)(void))taskGener
                             stats:(NSMutableDictionary *)stats;

- (void) cancel;
- (void) resume;
- (void) suspend;

@end

@interface QNDownloadManager : NSObject

@property (nonatomic) QNConfiguration *config;
@property (nonatomic) AFURLSessionManager *manager;
@property (nonatomic) QNStats *statsManager;

+ (BOOL) isValidIPAddress:(NSString *)ip;

- (instancetype) init;
- (instancetype) initWithConfiguration:(QNConfiguration*)config
                  sessionConfiguration:(AFURLSessionManager*)manager
                          statsManager:(QNStats*)statsManager;

- (NSData *) dataWithContentsOfURL:(NSString *) url;

- (QNSessionDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request
                                           progress:(NSProgress *__autoreleasing *)progress
                                        destination:(NSURL * (^__strong)(NSURL *__strong, NSURLResponse *__strong))destination
                                  completionHandler:(void (^__strong)(NSURLResponse *__strong, NSURL *__strong, NSError *__strong))completionHandler;

@end
