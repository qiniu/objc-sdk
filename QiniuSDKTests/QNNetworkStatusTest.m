//
//  QNNetworkStatusTest.m
//  QiniuSDK
//
//  Created by yangsen on 2022/6/10.
//  Copyright © 2022 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNNetworkStatusManager.h"
#import "QNUploadServerNetworkStatus.h"

@interface QNNetworkStatusTest : XCTestCase

@end

@implementation QNNetworkStatusTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGetNetworkStatus {
    NSString *host = @"qiniu.com";
    [kQNNetworkStatusManager updateNetworkStatus:host speed:100];
    QNNetworkStatus *status = [kQNNetworkStatusManager getNetworkStatus:host];
    XCTAssertEqual(status.speed, 100, @"getNetworkStatus error");
}

- (void)testNetworkStatusUpdate {
    NSString *host00 = @"qiniu.com";
    NSString *host01 = @"qiniu01.com";

    for (int i=0; i<100000; i++) {
        [kQNNetworkStatusManager updateNetworkStatus:host00 speed:100];
        [kQNNetworkStatusManager updateNetworkStatus:host01 speed:1000];
    }
    
    QNNetworkStatus *status00 = [kQNNetworkStatusManager getNetworkStatus:host00];
    XCTAssertEqual(status00.speed, 100, @"getNetworkStatus error");
    QNNetworkStatus *status01 = [kQNNetworkStatusManager getNetworkStatus:host01];
    XCTAssertEqual(status01.speed, 1000, @"getNetworkStatus error");
}

- (void)testNetworkStatusCompare {
    NSString *host00 = @"qiniu.com";
    NSString *host01 = @"qiniu01.com";
    [kQNNetworkStatusManager updateNetworkStatus:host00 speed:100];
    [kQNNetworkStatusManager updateNetworkStatus:host01 speed:1000];

    QNUploadServer *server00 = [QNUploadServer server:host00 ip:@"" source:@"c" ipPrefetchedTime:nil];
    QNUploadServer *server01 = [QNUploadServer server:host01 ip:@"" source:@"c" ipPrefetchedTime:nil];
    NSLog(@"==== start compare");
    for (int i=0; i<100000; i++) {
        BOOL isBetter = [QNUploadServerNetworkStatus isServerNetworkBetter:server00 thanServerB:server01];
        XCTAssertFalse(isBetter, @"should not better");
    }
}

@end
