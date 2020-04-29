//
//  XCTestCase+QNTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "XCTestCase+QNTest.h"
#import "objc/runtime.h"

@interface XCTestCase(QNTestPrivate)

@property(nonatomic, strong)NSDate *waitDeadline;

@end
@implementation XCTestCase(QNTest)

- (void)wait{
    [self waitForTime:24*3600];
}

- (void)waitForTime:(int)time{
    self.waitDeadline = [NSDate dateWithTimeInterval:time
                                           sinceDate:[NSDate date]];
    
    while ([self.waitDeadline timeIntervalSinceDate:[NSDate date]] > 0) {
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeInterval:0.01 sinceDate:[NSDate date]]];
    }
}

- (void)contine{
    self.waitDeadline = [NSDate dateWithTimeInterval:-1 sinceDate:[NSDate date]];
}


//MARK: --
#define kQNWaitDeadlineKey "waitDeadline"
- (NSDate *)waitDeadline{
    return objc_getAssociatedObject(self, kQNWaitDeadlineKey);
}
- (void)setWaitDeadline:(NSDate *)waitDeadline{
    objc_setAssociatedObject(self, kQNWaitDeadlineKey, waitDeadline, OBJC_ASSOCIATION_RETAIN);
}
@end
