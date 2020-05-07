//
//  QNBaseUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNBaseUpload.h"
#import "QNUploadDomainRegion.h"

@interface QNBaseUpload ()

@property (nonatomic, assign)NSInteger currentRegionIndex;
@property (nonatomic, strong)NSArray <id <QNUploadRegion> > *regions;

@end

@implementation QNBaseUpload
- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _currentRegionIndex = 0;
}

- (void)setConfig:(QNConfiguration *)config{
    _config = config;
    
    NSMutableArray *defaultRegions = [NSMutableArray array];
    NSArray *zoneInfos = [config.zone getZonesInfoWithToken:self.token].zonesInfo;
    for (QNZoneInfo *zoneInfo in zoneInfos) {
        QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
        [region setRegionData:zoneInfo];
        [defaultRegions addObject:region];
    }
    self.regions = [defaultRegions copy];
}

- (void)run {
    // rewrite by subclass
}

- (void)collectHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(uint64_t)fileOffset {
    
    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
    NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
    NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
    
    [Collector addRequestWithType:self.requestType httpResponseInfo:httpResponseInfo fileOffset:fileOffset targetRegionId:targetRegionId currentRegionId:currentRegionId identifier:self.identifier];
    
    uint64_t bytesSent;
    if (self.requestType == QNRequestType_mkblk || self.requestType == QNRequestType_bput) {
        if (httpResponseInfo.hasHttpResponse) {
            bytesSent = httpResponseInfo.bytesTotal;
        } else {
            bytesSent = 0;
        }
        [Collector append:CK_blockBytesSent value:@(bytesSent) identifier:self.identifier];
    } else {
        bytesSent = httpResponseInfo.bytesSent;
    }
    
    [Collector append:CK_totalBytesSent value:@(bytesSent) identifier:self.identifier];
}

- (void)collectUploadQualityInfo {
    
    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
    NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
    NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
    [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
    [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
    [Collector update:CK_fileSize value:@(self.size) identifier:self.identifier];
}


- (void)insertRegionAtFirst:(id <QNUploadRegion>)region{
    
}
- (BOOL)switchRegion{
    BOOL ret = NO;
    @synchronized (self) {
        _currentRegionIndex += 1;
        if (_currentRegionIndex < self.regions.count) {
            ret = YES;
        }
    }
    return ret;
}
- (id <QNUploadRegion>)getCurrentRegion{
    id <QNUploadRegion> region = nil;
    @synchronized (self) {
        NSLog(@"regions: %@ regionIndex:%lu", self.regions, self.currentRegionIndex);
        if (self.currentRegionIndex < self.regions.count) {
            region = self.regions[self.currentRegionIndex];
        }
    }
    return region;
}
@end
