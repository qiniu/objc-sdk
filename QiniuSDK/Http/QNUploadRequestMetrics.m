//
//  QNUploadRequestMetrics.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestMetrics.h"
#import "NSURLRequest+QNRequest.h"
#import "QNZoneInfo.h"

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

- (NSNumber *)totalElapsedTime{
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

- (NSNumber *)totalElapsedTime{
    if (self.metricsList) {
        double time = 0;
        for (QNUploadSingleRequestMetrics *metrics in self.metricsList) {
            time += metrics.totalElapsedTime.doubleValue;
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

- (void)addMetrics:(QNUploadRegionRequestMetrics*)metrics{
    if ([metrics.region.zoneInfo.regionId isEqualToString:self.region.zoneInfo.regionId]) {
        [_metricsListInter addObjectsFromArray:metrics.metricsListInter];
    }
}

- (NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    return [_metricsListInter copy];
}

@end


@interface QNUploadTaskMetrics()

@property (nonatomic,   copy) NSMutableDictionary<NSString *, QNUploadRegionRequestMetrics *> *metricsInfo;

@end
@implementation QNUploadTaskMetrics

+ (instancetype)emptyMetrics{
    QNUploadTaskMetrics *metrics = [[QNUploadTaskMetrics alloc] init];
    return metrics;
}

- (instancetype)init{
    if (self = [super init]) {
        _metricsInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSNumber *)totalElapsedTime{
    if (self.metricsInfo) {
        double time = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsInfo.allValues) {
            time += metrics.totalElapsedTime.doubleValue;
        }
        return time > 0 ? @(time) : nil;
    } else {
        return nil;
    }
}

- (NSNumber *)requestCount{
    if (self.metricsInfo) {
        NSInteger count = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsInfo.allValues) {
            count += metrics.requestCount.integerValue;
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (NSNumber *)bytesSend{
    if (self.metricsInfo) {
        long long bytes = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsInfo.allValues) {
            bytes += metrics.bytesSend.longLongValue;
        }
        return @(bytes);
    } else {
        return @(0);
    }
}

- (NSNumber *)regionCount{
    if (self.metricsInfo) {
        int count = 0;
        for (QNUploadRegionRequestMetrics *metrics in self.metricsInfo.allValues) {
            if (![metrics.region.zoneInfo.regionId isEqualToString:QNZoneInfoEmptyRegionId]) {
                count += 1;
            }
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (void)addMetrics:(QNUploadRegionRequestMetrics *)metrics{
    NSString *regionId = metrics.region.zoneInfo.regionId;
    if (!regionId) {
        return;
    }
    @synchronized (self) {
        QNUploadRegionRequestMetrics *metricsOld = self.metricsInfo[regionId];
        if (metricsOld) {
            [metricsOld addMetrics:metrics];
        } else {
            self.metricsInfo[regionId] = metrics;
        }
    }
}


@end
