//
//  QNUploadRequestMetrics.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestMetrics.h"

@interface QNUploadSingleRequestMetrics()
@end
@implementation QNUploadSingleRequestMetrics

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}
- (void)initData{
    _countOfRequestHeaderBytesSent = 0;
    _countOfRequestBodyBytesSent = 0;
    _countOfResponseHeaderBytesReceived = 0;
    _countOfResponseBodyBytesReceived = 0;
}

@end


@interface QNUploadRegionRequestMetrics()

@property (nonatomic, strong) id <QNUploadRegion> region;
@property (nonatomic,   copy) NSMutableArray<QNUploadSingleRequestMetrics *> *metricsListInter;

@end
@implementation QNUploadRegionRequestMetrics
- (instancetype)initWithRegion:(id<QNUploadRegion>)region{
    if (self = [super init]) {
        _region = region;
        _metricsListInter = [NSMutableArray array];
    }
    return self;
}
- (void)addMetrics:(QNUploadSingleRequestMetrics *)metrics{
    [_metricsListInter addObject:metrics];
}
- (NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    return [_metricsListInter copy];
}
@end


@interface QNUploadTaskMetrics()

@property (nonatomic, strong) NSArray<id <QNUploadRegion>> *regions;
@property (nonatomic,   copy) NSMutableArray<QNUploadSingleRequestMetrics *> *metricsListInter;

@end
@implementation QNUploadTaskMetrics
- (instancetype)initWithRegions:(NSArray<id<QNUploadRegion>> *)regions{
    if (self = [super init]) {
        _regions = regions;
        _metricsListInter = [NSMutableArray array];
    }
    return self;
}
- (void)addMetrics:(QNUploadSingleRequestMetrics *)metrics{
    [_metricsListInter addObject:metrics];
}
- (NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    return [_metricsListInter copy];
}
@end
