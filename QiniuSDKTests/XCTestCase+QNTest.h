//
//  XCTestCase+QNTest.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCTestCase(QNTest)

- (void)wait;

/// time：等待最长时间 单位：秒
- (void)waitForTime:(int)time;

- (void)contine;

@end

NS_ASSUME_NONNULL_END

#define QN_TEST_CASE_WAIT [self wait];
#define QN_TEST_CASE_WAIT_TIME(A) [self waitForTime:A];
#define QN_TEST_CASE_CONTINUE [self contine];

