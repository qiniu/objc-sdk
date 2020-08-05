//
//  QNAsyncRun.h
//  QiniuSDK
//
//  Created by bailong on 14/10/17.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kQNBackgroundQueue dispatch_get_global_queue(0, 0)
#define kQNMainQueue dispatch_get_main_queue()

typedef void (^QNRun)(void);

void QNAsyncRun(QNRun run);

void QNAsyncRunInMain(QNRun run);

void QNAsyncRunAfter(NSTimeInterval time, dispatch_queue_t queue, QNRun run);
