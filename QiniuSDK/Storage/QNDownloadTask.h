//
//  QNDownloadTask.h
//  QiniuSDK
//
//  Created by ltz on 10/2/15.
//  Copyright © 2015 Qiniu. All rights reserved.
//



#import <Foundation/Foundation.h>

void setStat(NSMutableDictionary *dic, id key, id value);



typedef NSURL * (^QNDestinationBlock)(NSURL *targetPath, NSURLResponse *response);
typedef void (^QNURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

@class QNDownloadManager;

@interface QNDownloadTask : NSObject<NSURLSessionDownloadDelegate>

#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

- (instancetype) initWithStats:(NSMutableDictionary *)stats
                       manager:(QNDownloadManager *)manager
                       request:(NSURLRequest *)request
                      progress:(NSProgress *)progress
                   destination:(QNDestinationBlock)destination
             completionHandler:(QNURLSessionTaskCompletionHandler)completionHandler;

- (void) cancel;
- (void) resume;
- (void) suspend;

#endif

@end

