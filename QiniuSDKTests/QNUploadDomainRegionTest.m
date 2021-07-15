//
//  QNUploadDomainRegionTest.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/20.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadDomainRegion.h"
#import "QNUploadServerFreezeManager.h"
#import "QNUploadServerFreezeUtil.h"
#import "QNZoneInfo.h"
#import "QNFixedZone.h"
#import <XCTest/XCTest.h>
#import <Photos/Photos.h>

@interface QNUploadDomainRegionTest : XCTestCase

@end

@implementation QNUploadDomainRegionTest

- (void)testGetOneServer {
    
    NSString *host = @"baidu.com";
    NSString *frozenType = QNUploadFrozenType(host, @"");
    QNFixedZone *zone = [[QNFixedZone alloc] initWithUpDomainList:@[host]];
    
    QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
    [region setupRegionData:[[zone getZonesInfoWithToken:nil].zonesInfo firstObject]];
    
    [kQNUploadGlobalHttp2Freezer freezeType:frozenType frozenTime:100];
    
    id<QNUploadServer> server = [region getNextServer:nil responseInfo:nil freezeServer:nil];
    
    XCTAssertNotNil(server, @"server is nil");
    
    PHAsset *asset = nil;
    PHContentEditingInputRequestOptions *options = nil;
    [asset requestContentEditingInputWithOptions:options completionHandler:^(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nonnull info) {
            
    }];
    PHContentEditingInput *input = nil;
}



@end
