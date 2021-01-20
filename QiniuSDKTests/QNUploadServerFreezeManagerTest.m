//
//  QNUploadServerFreezeManagerTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/20.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadServerFreezeManager.h"
#import <XCTest/XCTest.h>

@interface QNUploadServerFreezeManagerTest : XCTestCase

@end

@implementation QNUploadServerFreezeManagerTest

- (void)testFreeze {
    
    NSString *host = @"baidu.com";
    [kQNUploadServerFreezeManager freezeHost:host type:host frozenTime:10];
    
    BOOL isFrozen = [kQNUploadServerFreezeManager isFrozenHost:host type:host];
    XCTAssertTrue(isFrozen, "isFrozen false");
}

- (void)testUnfreeze {
    NSString *host = @"baidu.com";
    [kQNUploadServerFreezeManager freezeHost:host type:host frozenTime:10];
    
    BOOL isFrozen = [kQNUploadServerFreezeManager isFrozenHost:host type:host];
    XCTAssertTrue(isFrozen, "isFrozen false");
    
    [kQNUploadServerFreezeManager unfreezeHost:host type:host];
    isFrozen = [kQNUploadServerFreezeManager isFrozenHost:host type:host];
    XCTAssertTrue(isFrozen == NO, "isFrozen true");
}


@end
