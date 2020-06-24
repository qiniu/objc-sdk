//
//  QNFileRecorderTest.m
//  QiniuSDK
//
//  Created by bailong on 14/10/9.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QiniuSDK.h"

#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNFileRecorderTest : XCTestCase
@property QNUploadManager *upManager;
@property BOOL inTravis;
@end

@implementation QNFileRecorderTest

- (void)setUp {
    [super setUp];
    NSError *error = nil;
    QNFileRecorder *file = [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniutest"] error:&error];
    NSLog(@"recorder error %@", error);
    _upManager = [[QNUploadManager alloc] initWithRecorder:file];
#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
    NSString *travis = [[NSProcessInfo processInfo] environment][@"QINIU_TEST_ENV"];
    if ([travis isEqualToString:@"travis"]) {
        _inTravis = YES;
    }
#endif
}

- (void)testInit {
    NSError *error = nil;
    [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:@"qiniutest"] error:&error];
    XCTAssert(error == nil, @"Pass");
    [QNFileRecorder fileRecorderWithFolder:@"/qiniutest" error:&error];
    NSLog(@"file recorder %@", error);
    XCTAssert(error != nil, @"Pass");
    [QNFileRecorder fileRecorderWithFolder:@"/qiniutest" error:nil];
}

- (void) template:(int)size pos:(float)pos {
    NSString *keyUp = [NSString stringWithFormat:@"fileRecorder_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    __block NSString *key = nil;
    __block QNResponseInfo *info = nil;
    __block BOOL flag = NO;
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {

        if (percent >= pos) {
            flag = YES;
        }
        NSLog(@"progress %f", percent);
    }
        params:nil
        checkCrc:NO
        cancellationSignal:^BOOL() {
            return flag;
        }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    }
                 option:opt];
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isCancelled, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");

    // continue
    key = nil;
    info = nil;
    __block BOOL failed = NO;
    opt = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        if (percent < pos - 2 * 1024.0 / size) {
            failed = YES;
        }
        NSLog(@"continue progress %f,%f", percent, pos - 2 * 1024.0 / size);
    }
                                        params:nil
                                      checkCrc:NO
                            cancellationSignal:nil];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        key = k;
        info = i;
    }
                 option:opt];
    NSLog(@"failed: %@", failed ? @"YES" : @"NO");
    AGWW_WAIT_WHILE(key == nil, 60 * 30);
    NSLog(@"info %@", info);
    XCTAssert(info.isOK, @"Pass");
    XCTAssert(!failed, @"Pass");
    XCTAssert([keyUp isEqualToString:key], @"Pass");
    [tempFile remove];
}

- (void)tearDown {
    [super tearDown];
}

//- (void)test600k {
//    [self template:600 pos:0.7];
//}

//- (void)test700k {
//    [self template:700 pos:0.1];
//}

- (void)test3M {
    if (_inTravis) {
        return;
    }
    [self template:3 * 1024 + 1 pos:0.7];
}

- (void)test20M {
    if (_inTravis) {
        return;
    }
    [self template:20 * 1024 + 1 pos:0.7];
}

//#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED

//- (void)test1M {
//    if (_inTravis) {
//        return;
//    }
//    [self template:1024 pos:0.51];
//}

//- (void)test4M {
//    if (_inTravis) {
//        return;
//    }
//    [self template:4 * 1024 pos:0.9];
//}

- (void)test8M {
    if (_inTravis) {
        return;
    }
    [self template:8 * 1024 + 1 pos:0.7];
}

//#endif

@end
