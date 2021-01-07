//
//  QNSingleFlightTest.m
//  QiniuSDK
//
//  Created by yangsen on 2021/1/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper/AGAsyncTestHelper.h>
#import "QNSingleFlight.h"

@interface QNSingleFlightTest : XCTestCase

@end

@implementation QNSingleFlightTest

#define RetryCount 5
- (void)testSync {
    
    int maxCount = 1000;
    __block int completeCount = 0;
    QNSingleFlight *singleFlight = [[QNSingleFlight alloc] init];
    for (int i = 0; i < maxCount; i++) {
        [self singleFlightPerform:singleFlight index:i retryCount:RetryCount isAsync:false complete:^{
            completeCount += 1;
            NSLog(@"== sync completeCount:%d", completeCount);
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 60);
}

- (void)testSyncRetry {
    
    int maxCount = 1000;
    __block int completeCount = 0;
    QNSingleFlight *singleFlight = [[QNSingleFlight alloc] init];
    for (int i = 0; i < maxCount; i++) {
        [self singleFlightPerform:singleFlight index:i retryCount:0 isAsync:false complete:^{
            completeCount += 1;
            NSLog(@"== sync completeCount:%d", completeCount);
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 60);
}

- (void)testAsync {
    
    int maxCount = 1000;
    __block int completeCount = 0;
    QNSingleFlight *singleFlight = [[QNSingleFlight alloc] init];
    for (int i = 0; i < maxCount; i++) {
        [self singleFlightPerform:singleFlight index:i retryCount:RetryCount isAsync:true complete:^{
            @synchronized (self) {
                completeCount += 1;
            }
            NSLog(@"== async completeCount:%d", completeCount);
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 10);
}

- (void)testAsyncRetry {
    
    int maxCount = 1000;
    __block int completeCount = 0;
    QNSingleFlight *singleFlight = [[QNSingleFlight alloc] init];
    for (int i = 0; i < maxCount; i++) {
        [self singleFlightPerform:singleFlight index:i retryCount:0 isAsync:true complete:^{
            @synchronized (self) {
                completeCount += 1;
            }
            NSLog(@"== async completeCount:%d", completeCount);
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 10);
}


- (void)singleFlightPerform:(QNSingleFlight *)singleFlight
                      index:(int)index
                 retryCount:(int)retryCount
                    isAsync:(BOOL)isAsync
                   complete:(dispatch_block_t)complete {
    
    __weak typeof(self) weakSelf = self;
    [singleFlight perform:@"key" action:^(QNSingleFlightComplete  _Nonnull complete) {
        
        NSString *indexString = [NSString stringWithFormat:@"%d", index];
        
        dispatch_block_t completeBlock = ^(){
            if (retryCount < RetryCount) {
                NSLog(@"== %@ action retryCount:%d index:%d error", isAsync ? @"async" : @"sync", retryCount, index);
                complete(nil, [[NSError alloc] initWithDomain:NSArgumentDomain code:-1 userInfo:nil]);
            } else {
                NSLog(@"== %@ action retryCount:%d index:%d value", isAsync ? @"async" : @"sync", retryCount, index);
                complete(indexString, nil);
            }
        };
        if (isAsync) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                completeBlock();
            });
        } else {
            completeBlock();
        }
    } complete:^(id  _Nonnull value, NSError * _Nonnull error) {
        __strong typeof(self) self = weakSelf;
        
        if (retryCount < RetryCount) {
            [self singleFlightPerform:singleFlight index:index retryCount:retryCount+1 isAsync:isAsync complete:complete];
        } else {
            NSString *indexString = [NSString stringWithFormat:@"%d", index];
            NSLog(@"== %@ action complete retryCount:%d value:%@ index:%d", isAsync ? @"async" : @"sync", retryCount, value, index);
        
            if (!isAsync) {
                XCTAssertTrue(value != nil, @"Pass");
                XCTAssertTrue(error == nil, @"Pass");
                XCTAssertTrue([(NSString *)value isEqualToString:indexString], @"Pass");
            } else {
                XCTAssertTrue((value != nil || error != nil), @"Pass");
            }
            
            complete();
        }
    }];
}

@end
