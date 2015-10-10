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
#import "QNDownloadTask.h"


typedef NSURL * (^QNDestinationBlock)(NSURL *targetPath, NSURLResponse *response);
typedef void (^QNURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

@interface QNDownloadManager : NSObject

#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

@property (nonatomic) QNStats *statsManager;
@property (nonatomic) QNConfiguration *config;

- (instancetype) init;
- (instancetype) initWithConfiguration:(QNConfiguration*)config
                  sessionConfiguration:(AFURLSessionManager*)manager
                          statsManager:(QNStats*)statsManager;

- (QNDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request
                                    progress:(NSProgress *)progress
                                 destination:(NSURL * (^__strong)(NSURL *__strong, NSURLResponse *__strong))destination
                           completionHandler:(void (^__strong)(NSURLResponse *__strong, NSURL *__strong, NSError *__strong))completionHandler;

#endif

@end

