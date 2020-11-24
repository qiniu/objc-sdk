//
//  QNUploadDomainRegionTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/20.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadDomainRegion.h"
#import "QNUtils.h"
#import "QNUploadServerFreezeManager.h"
#import "QNZoneInfo.h"
#import "QNFixedZone.h"
#import <XCTest/XCTest.h>

@interface QNUploadDomainRegionTest : XCTestCase

@end

@implementation QNUploadDomainRegionTest

- (void)testGetOneServer {
    
    NSString *host = @"baidu.com";
    NSString *type = [QNUtils getIpType:nil host:host];
    QNFixedZone *zone = [[QNFixedZone alloc] initWithUpDomainList:@[host]];
    
    QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
    [region setupRegionData:[[zone getZonesInfoWithToken:nil].zonesInfo firstObject]];
    
    [kQNUploadServerFreezeManager freezeHost:host type:type frozenTime:100];
    
    id<QNUploadServer> server = [region getNextServer:NO responseInfo:nil freezeServer:nil];
    
    XCTAssertNotNil(server, @"PASS");
}



@end
