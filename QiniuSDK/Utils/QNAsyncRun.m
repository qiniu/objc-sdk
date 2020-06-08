//
//  QNAsyncRun.m
//  QiniuSDK
//
//  Created by bailong on 14/10/17.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import <Foundation/Foundation.h>

void QNAsyncRun(QNRun run) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        run();
    });
}

void QNAsyncRunInMain(QNRun run) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        run();
    });
}

void QNAsyncRunAfter(NSTimeInterval time, dispatch_queue_t queue, QNRun run) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), queue, ^{
        run();
    });
}
