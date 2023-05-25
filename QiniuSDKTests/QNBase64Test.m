//
//  QNBase64Test.m
//  QiniuSDK
//
//  Created by bailong on 14/9/30.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QiniuSDK.h"
#import <XCTest/XCTest.h>

@interface Demo : NSObject
@property(nonatomic,   copy) NSString   *title;
@property(nonatomic, strong) NSLock     *locker;
@property(nonatomic, strong) NSArray    *object;
@end
@implementation Demo
-(instancetype)init{
    if (self = [super init]) {
        self.locker = [[NSLock alloc] init];
    }
    return self;
}
-(NSArray *)object{
//    [self.locker lock];
    if (_object == nil) {
        _object = @[self.title];
    }
//    [self.locker unlock];
    return _object;
}
@end
@interface QNBase64Test : XCTestCase

@end

@implementation QNBase64Test

- (void)testEncode {
    // This is an example of a functional test case.
    NSString *source = @"你好/+=";
    NSString *encode = [QNUrlSafeBase64 encodeString:source];
    XCTAssert([encode isEqual:@"5L2g5aW9Lys9"], @"encode: %@", encode);
}


- (void)testA {
    for (int i=0; i<1000; i++) {
        Demo *demo = [[Demo alloc] init];
        __weak Demo *weak = demo;
        void (^create)(int) = ^(int index) {
            __strong Demo *strong = weak;
//            Demo *strong = demo;
            int ip = index;
            NSLog(@">> %d",ip);
            strong.title = [NSString stringWithFormat:@"== %d ==", ip];
            NSLog(@"<< %@:%d", strong.object, ip);
            NSLog(@"<< %@:%lu:%d", strong.object, (unsigned long)[strong.object count], ip);
        };
        
        dispatch_group_t group = dispatch_group_create();
        for (int j=0; j<10; j++) {
            dispatch_group_enter(group);
            dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
                dispatch_group_leave(group);
                create(j);
            });
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        NSLog(@"== \n\n ==");
    }
}

@end



