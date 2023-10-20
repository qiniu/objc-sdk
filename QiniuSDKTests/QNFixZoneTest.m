//
//  QNFixZoneTest.m
//  QiniuSDK
//
//  Created by yangsen on 2023/9/7.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QNFixedZone.h"
#import "QNZoneInfo.h"

@interface QNFixZoneTest : XCTestCase

@end

@implementation QNFixZoneTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCreateByRegionId {
    QNFixedZone *zone = [QNFixedZone createWithRegionId:@"na0"];
    QNZoneInfo *zoneInfo = [zone getZonesInfoWithToken:nil].zonesInfo[0];
    
    XCTAssert([zoneInfo.regionId isEqualToString:@"na0"], @"regionId:%@", zoneInfo.regionId);
    XCTAssert([zoneInfo.domains[0] isEqualToString:@"upload-na0.qiniup.com"], @"domains:%@", zoneInfo.domains);
    XCTAssert([zoneInfo.domains[1] isEqualToString:@"up-na0.qiniup.com"], @"domains:%@", zoneInfo.domains);
}

@end
