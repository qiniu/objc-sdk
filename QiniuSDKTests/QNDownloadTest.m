//
//  QNDownloadTest.m
//  QiniuSDK
//
//  Created by ltz on 9/28/15.
//  Copyright (c) 2015 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>

#import "QNConfiguration.h"
#import "QNDownloadManager.h"

@interface QNDownloadTest : XCTestCase
#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

@property QNDownloadManager *dnManager;
#endif

@end

@implementation QNDownloadTest

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.

#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

	QNConfigurationBuilder *builder = [[QNConfigurationBuilder alloc] init];
	builder.pushStatIntervalS = 1;
	QNConfiguration *cfg = [[QNConfiguration alloc] initWithBuilder:builder];
	QNStats *stats = [[QNStats alloc] initWithConfiguration:cfg];
	_dnManager = [[QNDownloadManager alloc] initWithConfiguration:cfg sessionConfiguration:nil statsManager:stats];
#endif
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testDownload {
#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

	NSURL *URL = [NSURL URLWithString:@"http://ztest.qiniudn.com/gogopher.jpg"];

	NSURLRequest *request = [NSURLRequest requestWithURL:URL];
	__block bool done = false;
	__block NSError *dErr = nil;

	NSLog(@"start download");
	QNDownloadTask *task = [_dnManager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {

	                                NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
	                                NSURL *u = [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
	                                NSLog(@"targetPath: %@", targetPath);
	                                NSLog(@"urll: %@", u.absoluteString);
	                                return u;
				} completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
	                                NSLog(@"File downloaded to: %@", filePath);
	                                if (error) {
	                                        dErr = [error copy];
					}
	                                NSLog(@"download error: %@", error);

	                                [_dnManager.statsManager pushStats];
	                                done = true;
	                                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
				}];
	[task resume];

	AGWW_WAIT_WHILE(done==false, 60*30);
	AGWW_WAIT_WHILE(_dnManager.statsManager.count == 0, 60);

	XCTAssertNil(dErr, @"Pass");

#endif

}

/*
   - (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
   }
 */

@end

