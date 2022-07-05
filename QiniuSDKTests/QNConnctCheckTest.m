//
//  QNConnctCheckTest.m
//  QiniuSDK
//
//  Created by yangsen on 2021/1/13.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNLogUtil.h"
#import "QNConfiguration.h"
#import "QNConnectChecker.h"

@interface QNConnctCheckTest : XCTestCase

@end

@implementation QNConnctCheckTest

- (void)setUp {
//    [QNLogUtil setLogLevel:QNLogLevelInfo];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCheck {
    int maxCount = 100;
    int successCount = 0;
    for (int i = 0; i < maxCount; i++) {
        if ([QNConnectChecker isConnected:[QNConnectChecker check]]) {
            successCount += 1;
        }
    }
    
    XCTAssertTrue(maxCount == successCount, @"maxCount:%d successCount:%d", maxCount, successCount);
}

- (void)testCustomCheckHosts {
    kQNGlobalConfiguration.connectCheckURLStrings = @[@"https://www.baidu.com"];
    
    int maxCount = 100;
    int successCount = 0;
    for (int i = 0; i < maxCount; i++) {
        if ([QNConnectChecker isConnected:[QNConnectChecker check]]) {
            successCount += 1;
        }
    }
    
    XCTAssertTrue(maxCount == successCount, @"maxCount:%d successCount:%d", maxCount, successCount);
}

- (void)testNotConnected {
    kQNGlobalConfiguration.connectCheckURLStrings = @[@"https://www.test1.com", @"https://www.test2.com"];
    
    int maxCount = 10;
    int successCount = 0;
    for (int i = 0; i < maxCount; i++) {
        if ([QNConnectChecker isConnected:[QNConnectChecker check]]) {
            successCount += 1;
        }
    }
    
    XCTAssertTrue(successCount == 0, @"successCount:%d", successCount);
}

@end
