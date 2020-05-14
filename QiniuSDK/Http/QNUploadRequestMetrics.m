//
//  QNUploadRequestMetrics.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestMetrics.h"
#import "NSURLRequest+QNRequest.h"

@interface QNUploadSingleRequestMetrics()
@end
@implementation QNUploadSingleRequestMetrics

+ (instancetype)emptyMetrics{
    QNUploadSingleRequestMetrics *metrics = [[QNUploadSingleRequestMetrics alloc] init];
    return metrics;
}

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

- (NSNumber *)totalElaspsedTime{
    return [self timeFromStartDate:self.startDate
                         toEndDate:self.endDate];
}

- (NSNumber *)totalDnsTime{
    return [self timeFromStartDate:self.domainLookupStartDate
                         toEndDate:self.domainLookupEndDate];
}

- (NSNumber *)totalConnectTime{
    return [self timeFromStartDate:self.connectStartDate
                         toEndDate:self.connectEndDate];
}

- (NSNumber *)totalSecureConnectTime{
    return [self timeFromStartDate:self.secureConnectionStartDate
                         toEndDate:self.secureConnectionEndDate];
}

- (NSNumber *)totalRequestTime{
    return [self timeFromStartDate:self.requestStartDate
                         toEndDate:self.requestEndDate];
}

- (NSNumber *)totalWaitTime{
    return [self timeFromStartDate:self.requestEndDate
                         toEndDate:self.responseStartDate];
}

- (NSNumber *)totalResponseTime{
    return [self timeFromStartDate:self.responseStartDate
                         toEndDate:self.responseEndDate];
}

- (NSNumber *)totalBytes{
    NSInteger headerLength = [NSString stringWithFormat:@"%@", self.request.allHTTPHeaderFields].length;
    NSInteger bodyLength = [self.request.qn_getHttpBody length];
    return @(headerLength + bodyLength);
}

- (NSNumber *)bytesSend{
    int64_t totalBytes = [self totalBytes].integerValue;
    int64_t senderBytes = self.countOfRequestBodyBytesSent + self.countOfRequestHeaderBytesSent;
    int64_t bytes = MIN(totalBytes, senderBytes);
    return @(bytes);
}

- (NSNumber *)timeFromStartDate:(NSDate *)startDate toEndDate:(NSDate *)endDate{
    if (startDate && endDate) {
        double time = [endDate timeIntervalSinceDate:startDate] * 1000;
        return @(time);
    } else {
        return nil;
    }
}
@end


@interface QNUploadRegionRequestMetrics()

@property (nonatomic, strong) id <QNUploadRegion> region;
@property (nonatomic,   copy) NSMutableArray<QNUploadSingleRequestMetrics *> *metricsListInter;

@end
@implementation QNUploadRegionRequestMetrics

+ (instancetype)emptyMetrics{
    QNUploadRegionRequestMetrics *metrics = [[QNUploadRegionRequestMetrics alloc] init];
    return metrics;
}

- (instancetype)initWithRegion:(id<QNUploadRegion>)region{
    if (self = [super init]) {
        _region = region;
        _metricsListInter = [NSMutableArray array];
    }
    return self;
}

- (NSNumber *)totalElaspsedTime{
    if (self.metricsList) {
        double time = 0;
        for (QNUploadSingleRequestMetrics *metrics in self.metricsList) {
            time += metrics.totalElaspsedTime.doubleValue;
        }
        return time > 0 ? @(time) : nil;
    } else {
        return nil;
    }
}

- (NSNumber *)requestCount{
    if (self.metricsList) {
        return @(self.metricsList.count);
    } else {
        return @(0);
    }
}

- (NSNumber *)bytesSend{
    if (self.metricsList) {
        long long bytes = 0;
        for (QNUploadSingleRequestMetrics *metrics in self.metricsList) {
            bytes += metrics.bytesSend.longLongValue;
        }
        return @(bytes);
    } else {
        return @(0);
    }
}

- (void)addMetricsList:(NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    [_metricsListInter addObjectsFromArray:metricsList];
}

- (NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    return [_metricsListInter copy];
}

@end


@interface QNUploadTaskMetrics()

@property (nonatomic, strong) NSArray<id <QNUploadRegion>> *regions;
@property (nonatomic,   copy) NSMutableArray<QNUploadRegionRequestMetrics *> *metricsListInter;

@end
@implementation QNUploadTaskMetrics

+ (instancetype)emptyMetrics{
    QNUploadTaskMetrics *metrics = [[QNUploadTaskMetrics alloc] init];
    return metrics;
}

- (instancetype)initWithRegions:(NSArray<id<QNUploadRegion>> *)regions{
    if (self = [super init]) {
        _regions = regions;
        _metricsListInter = [NSMutableArray array];
    }
    return self;
}

- (NSNumber *)totalElaspsedTime{
    if (self.metricsList) {
        double time = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsList) {
            time += metrics.totalElaspsedTime.doubleValue;
        }
        return time > 0 ? @(time) : nil;
    } else {
        return nil;
    }
}

- (NSNumber *)requestCount{
    if (self.metricsList) {
        NSInteger count = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsList) {
            count += metrics.requestCount.integerValue;
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (NSNumber *)bytesSend{
    if (self.metricsList) {
        long long bytes = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsList) {
            bytes += metrics.bytesSend.longLongValue;
        }
        return @(bytes);
    } else {
        return @(0);
    }
}

- (NSNumber *)regionCount{
    if (self.regions) {
        return @(self.regions.count);
    } else {
        return @(0);
    }
}

- (void)addMetrics:(QNUploadRegionRequestMetrics *)metrics{
    @synchronized (self) {
        [_metricsListInter addObject:metrics];
    }
}
- (NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    return [_metricsListInter copy];
}


@end
