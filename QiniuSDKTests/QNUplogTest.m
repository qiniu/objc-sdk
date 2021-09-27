//
//  QNUplogTest.m
//  QiniuSDK
//
//  Created by yangsen on 2021/9/8.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QNDnsPrefetch.h"
#import "QNConfiguration.h"
#import "QNTestConfig.h"
#import "QNReportItem.h"
#import "QNUploadInfoReporter.h"


@interface QNUplogTest : XCTestCase

@end

@implementation QNUplogTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testUplog{
    
    kQNGlobalConfiguration.isDnsOpen = YES;
    [[QNTransactionManager shared] addDnsLocalLoadTransaction];
    
    while (true) {
        NSArray *ips = [kQNDnsPrefetch getInetAddressByHost:@"uplog.qbox.me"];
        if (ips != nil && ips.count > 0) {
            break;
        }
        sleep(1);
    }
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeRequest forKey:QNReportRequestKeyLogType];
    [item setReportValue:@1620372409 forKey:QNReportRequestKeyUpTime];
    [item setReportValue:@200 forKey:QNReportRequestKeyStatusCode];
    [item setReportValue:@"NNKOBBIJKKO" forKey:QNReportRequestKeyRequestId];
    [item setReportValue:@"domain" forKey:QNReportRequestKeyHost];
    [item setReportValue:@"remoteAddress" forKey:QNReportRequestKeyRemoteIp];
    [item setReportValue:@80 forKey:QNReportRequestKeyPort];
    [item setReportValue:@"bucket" forKey:QNReportRequestKeyTargetBucket];
    [item setReportValue:@"key" forKey:QNReportRequestKeyTargetKey];
    [item setReportValue:@12345 forKey:QNReportRequestKeyTotalElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyDnsElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyConnectElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyTLSConnectElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyRequestElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyWaitElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyResponseElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyResponseElapsedTime];
    [item setReportValue:@123 forKey:QNReportRequestKeyFileOffset];
    [item setReportValue:@123 forKey:QNReportRequestKeyBytesSent];
    [item setReportValue:@123 forKey:QNReportRequestKeyBytesTotal];
    [item setReportValue:@123 forKey:QNReportRequestKeyPid];
    [item setReportValue:@123 forKey:QNReportRequestKeyTid];
    [item setReportValue:@"regionId" forKey:QNReportRequestKeyTargetRegionId];
    [item setReportValue:@"regionId" forKey:QNReportRequestKeyCurrentRegionId];
    [item setReportValue:@"error" forKey:QNReportRequestKeyErrorType];
    [item setReportValue:@"errorDesc" forKey:QNReportRequestKeyErrorDescription];
    [item setReportValue:@"form" forKey:QNReportRequestKeyUpType];
    [item setReportValue:@"systemName" forKey:QNReportRequestKeyOsName];
    [item setReportValue:@"systemVersion" forKey:QNReportRequestKeyOsVersion];
    [item setReportValue:@"oc" forKey:QNReportRequestKeySDKName];
    [item setReportValue:@"8.3.3" forKey:QNReportRequestKeySDKVersion];
    [item setReportValue:@1620372409 forKey:QNReportRequestKeyClientTime];
    [item setReportValue:@"wifi" forKey:QNReportRequestKeyNetworkType];
    [item setReportValue:@-1 forKey:QNReportRequestKeySignalStrength];
    
    [item setReportValue:@"server" forKey:QNReportRequestKeyPrefetchedDnsSource];
    [item setReportValue:@12 forKey:QNReportRequestKeyPrefetchedBefore];

    [item setReportValue:@"dns error" forKey:QNReportRequestKeyPrefetchedErrorMessage];
    
    [item setReportValue:@"http1.1" forKey:QNReportRequestKeyHttpVersion];

    [item setReportValue:@"disable" forKey:QNReportRequestKeyNetworkMeasuring];

    // 劫持标记
    [item setReportValue:@"hijacked" forKey:QNReportRequestKeyHijacking];
    [item setReportValue:@"server" forKey:QNReportRequestKeyDnsSource];
    [item setReportValue:@"dns error" forKey:QNReportRequestKeyDnsErrorMessage];
    
    // 成功统计速度
    [item setReportValue:@123456 forKey:QNReportRequestKeyPerceptiveSpeed];
    
    [kQNReporter reportItem:item token:token_na0];
    
//    AGWW_WAIT_WHILE(YES, 5 * 60);
}


@end
