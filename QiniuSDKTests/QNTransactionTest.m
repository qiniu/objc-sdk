//
//  QNTransactionTest.m
//  QiniuSDK_MacTests
//
//  Created by yangsen on 2020/4/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNTransactionManager.h"
#import "XCTestCase+QNTest.h"

@interface QNTransactionTest : XCTestCase

@end

@implementation QNTransactionTest

- (void)setUp {
    [kQNTransactionManager destroyResource];
}

- (void)tearDown {
    [super tearDown];
    [kQNTransactionManager destroyResource];
}

- (void)testTransaction {
    
    QNTransaction *normal = [QNTransaction transaction:@"1" after:0 action:^{
        NSLog(@"1");
    }];
    XCTAssert(normal, @"normal is nil");
    
    QNTransaction *time = [QNTransaction timeTransaction:@"2"
                                                   after:0
                                                interval:1
                                                  action:^{
        NSLog(@"2");
    }];
    XCTAssert(time, @"time is nil");
}

- (void)testTransactionManagerAddAndRemove {
    
    [kQNTransactionManager destroyResource];
    
    QNTransaction *transaction01 = [QNTransaction transaction:@"1" after:0 action:^{
        NSLog(@"== 1 == %@", [NSThread currentThread]);
    }];
    QNTransaction *transaction02 = [QNTransaction timeTransaction:@"2"
                                                            after:0
                                                         interval:1
                                                           action:^{
        NSLog(@"== 2 == %@", [NSThread currentThread]);
    }];
    
    QNTransactionManager *manager = [QNTransactionManager shared];
    [manager addTransaction:transaction01];
    [manager addTransaction:transaction02];
    QNTransaction *header = [manager valueForKeyPath:@"transactionList.header"];

    XCTAssert((header == transaction01) || (header == transaction02) || (header == nil), @"header:%@ transaction01:%@", header, transaction01);
    
    [manager removeTransaction:transaction01];
    
    header = [manager valueForKeyPath:@"transactionList.header"];
    NSLog(@"header: %@", header.name);
    XCTAssert((header == transaction02) || (header == nil), @"header:%@ transaction02:%@", header, transaction02);

    [manager removeTransaction:transaction02];
    
    header = [manager valueForKeyPath:@"transactionList.header"];
    NSLog(@"header: %@", header.name);
    XCTAssert(header == nil, @"header:%@", header);

    QNTransaction *transaction03 = [QNTransaction transaction:@"3" after:0 action:^{
        NSLog(@"3");
    }];
    QNTransaction *transaction04 = [QNTransaction timeTransaction:@"4"
                                                            after:0
                                                         interval:1
                                                           action:^{
        NSLog(@"4");
    }];
    [manager addTransaction:transaction03];
    [manager addTransaction:transaction04];
    
    
    QN_TEST_CASE_WAIT_TIME(5);
    
    header = [manager valueForKeyPath:@"transactionList.header"];
    NSLog(@"header: %@", header.name);
    XCTAssert(header == transaction04, @"header:%@ transaction04:%@", header, transaction04);
}

@end
