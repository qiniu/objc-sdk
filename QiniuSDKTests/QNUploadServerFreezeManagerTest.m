//
//  QNUploadServerFreezeManagerTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/20.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadServerFreezeUtil.h"
#import "QNUploadServerFreezeManager.h"
#import <XCTest/XCTest.h>

@interface QNUploadServerFreezeManagerTest : XCTestCase

@end

@implementation QNUploadServerFreezeManagerTest

- (void)testFreeze {
    
    NSString *host = @"baidu.com";
    NSString *frozenType = QNUploadFrozenType(host, @"");
    
    [kQNUploadGlobalHttp2Freezer freezeType:frozenType frozenTime:10];
    BOOL isFrozen = [kQNUploadGlobalHttp2Freezer isTypeFrozen:frozenType];
    XCTAssertTrue(isFrozen, "http2 isFrozen false");
    
    [kQNUploadGlobalHttp3Freezer freezeType:frozenType frozenTime:10];
    isFrozen = [kQNUploadGlobalHttp3Freezer isTypeFrozen:frozenType];
    XCTAssertTrue(isFrozen, "http3 isFrozen false");
}

- (void)testUnfreeze {
    NSString *host = @"baidu.com";
    NSString *frozenType = QNUploadFrozenType(host, @"");
    
    [kQNUploadGlobalHttp2Freezer freezeType:frozenType frozenTime:10];
    BOOL isFrozen = [kQNUploadGlobalHttp2Freezer isTypeFrozen:frozenType];
    XCTAssertTrue(isFrozen, "http2 isFrozen false");
    
    [kQNUploadGlobalHttp2Freezer unfreezeType:frozenType];
    isFrozen = [kQNUploadGlobalHttp2Freezer isTypeFrozen:frozenType];
    XCTAssertTrue(isFrozen == NO, "http2 isFrozen true");
}


@end
