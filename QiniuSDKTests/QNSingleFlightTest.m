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

- (void)testSync {
    
    int maxCount = 1000;
    __block int completeCount = 0;
    __block int successCount = 0;
    QNSingleFlight *singleFlight = [[QNSingleFlight alloc] init];
    for (int i = 0; i < maxCount; i++) {
        [singleFlight perform:@"key" action:^(QNSingleFlightComplete  _Nonnull complete) {
            NSString *index = [NSString stringWithFormat:@"%d", i];
            NSLog(@"== sync action value: %@", index);
            complete(index, nil);
            
        } complete:^(id  _Nonnull value, NSError * _Nonnull error) {
            NSString *index = [NSString stringWithFormat:@"%d", i];
            if ([(NSString *)value isEqualToString:index]) {
                successCount += 1;
            }
            completeCount += 1;
            NSLog(@"== sync complete value: %@ completeCount:%d", value, completeCount);
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 60);
    XCTAssertTrue(successCount == maxCount, @"Pass");
}

- (void)testAsync {
    
    int maxCount = 1000;
    __block int completeCount = 0;
    QNSingleFlight *singleFlight = [[QNSingleFlight alloc] init];
    for (int i = 0; i < maxCount; i++) {
        [singleFlight perform:@"key" action:^(QNSingleFlightComplete  _Nonnull complete) {
            NSString *index = [NSString stringWithFormat:@"%d", i];
            NSLog(@"== async action value: %@", index);
            
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                complete(index, nil);
            });
    
        } complete:^(id  _Nonnull value, NSError * _Nonnull error) {
            @synchronized (self) {
                completeCount += 1;
            }
            NSLog(@"== async complete value: %@ completeCount:%d", value, completeCount);
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 10);
    XCTAssertTrue(completeCount == maxCount, @"Pass");
}


@end
