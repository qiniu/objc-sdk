//
//  QNUploadRequestMetrics.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUtils.h"
#import "QNUploadRequestMetrics.h"
#import "NSURLRequest+QNRequest.h"
#import "QNZoneInfo.h"

@interface QNUploadMetrics()

@property (nullable, strong) NSDate *startDate;
@property (nullable, strong) NSDate *endDate;

@end
@implementation QNUploadMetrics
//MARK:-- 构造
+ (instancetype)emptyMetrics {
    return [[self alloc] init];
}

- (NSNumber *)totalElapsedTime{
    return [QNUtils dateDuration:self.startDate endDate:self.endDate];
}

- (void)start {
    self.startDate = [NSDate date];
}

- (void)end {
    self.endDate = [NSDate date];
}
@end

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

- (void)setRequest:(NSURLRequest *)request{
    NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:request.URL
                                                              cachePolicy:request.cachePolicy
                                                          timeoutInterval:request.timeoutInterval];
    newRequest.allHTTPHeaderFields = request.allHTTPHeaderFields;
    
    NSInteger headerLength = [NSString stringWithFormat:@"%@", request.allHTTPHeaderFields].length;
    NSInteger bodyLength = [request.qn_getHttpBody length];
    _totalBytes = @(headerLength + bodyLength);
    _request = [newRequest copy];
}

- (void)setResponse:(NSURLResponse *)response {
    if (_countOfRequestBodyBytesSent <= 0) {
        _countOfRequestBodyBytesSent = response.expectedContentLength;
    }
    if (_countOfResponseHeaderBytesReceived <= 0 && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        _countOfResponseHeaderBytesReceived = [NSString stringWithFormat:@"%@", [(NSHTTPURLResponse *)response allHeaderFields]].length;
    }
    _response = [response copy];
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

- (NSNumber *)bytesSend{
    int64_t totalBytes = [self totalBytes].integerValue;
    int64_t senderBytes = self.countOfRequestBodyBytesSent + self.countOfRequestHeaderBytesSent;
    int64_t bytes = MIN(totalBytes, senderBytes);
    return @(bytes);
}

- (NSNumber *)timeFromStartDate:(NSDate *)startDate toEndDate:(NSDate *)endDate{
    return [QNUtils dateDuration:startDate endDate:endDate];
}

- (NSNumber *)perceptiveSpeed {
    int64_t size = self.bytesSend.longLongValue + _countOfResponseHeaderBytesReceived + _countOfResponseBodyBytesReceived;
    if (size == 0 || self.totalElapsedTime == nil) {
        return nil;
    }
    
    return [QNUtils calculateSpeed:size totalTime:self.totalElapsedTime.longLongValue];
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
    @synchronized (self) {
        [_metricsListInter addObjectsFromArray:metricsList];
    }
}

- (void)addMetrics:(QNUploadRegionRequestMetrics*)metrics{
    if ([metrics.region.zoneInfo.regionId isEqualToString:self.region.zoneInfo.regionId]) {
        @synchronized (self) {
            [_metricsListInter addObjectsFromArray:metrics.metricsListInter];
        }
    }
}

- (NSArray<QNUploadSingleRequestMetrics *> *)metricsList{
    @synchronized (self) {
        return [_metricsListInter copy];
    }
}

@end


@interface QNUploadTaskMetrics()

@property (nonatomic,   copy) NSString *upType;
@property (nonatomic,   copy) NSMutableDictionary<NSString *, QNUploadRegionRequestMetrics *> *metricsInfo;

@end
@implementation QNUploadTaskMetrics

+ (instancetype)emptyMetrics{
    QNUploadTaskMetrics *metrics = [[QNUploadTaskMetrics alloc] init];
    return metrics;
}

+ (instancetype)taskMetrics:(NSString *)upType {
    QNUploadTaskMetrics *metrics = [self emptyMetrics];
    metrics.upType = upType;
    return metrics;
}

- (instancetype)init{
    if (self = [super init]) {
        _metricsInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSNumber *)totalElapsedTime{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        double time = 0;
        for (QNUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            time += metrics.totalElapsedTime.doubleValue;
        }
        return time > 0 ? @(time) : nil;
    } else {
        return nil;
    }
}

- (NSNumber *)requestCount{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        NSInteger count = 0;
        for (QNUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            count += metrics.requestCount.integerValue;
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (NSNumber *)bytesSend{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        long long bytes = 0;
        for (QNUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            bytes += metrics.bytesSend.longLongValue;
        }
        return @(bytes);
    } else {
        return @(0);
    }
}

- (NSNumber *)regionCount{
    NSDictionary *metricsInfo = [self syncCopyMetricsInfo];
    if (metricsInfo) {
        int count = 0;
        for (QNUploadRegionRequestMetrics *metrics in metricsInfo.allValues) {
            if (![metrics.region.zoneInfo.regionId isEqualToString:QNZoneInfoEmptyRegionId]) {
                count += 1;
            }
        }
        return @(count);
    } else {
        return @(0);
    }
}

- (void)setUcQueryMetrics:(QNUploadRegionRequestMetrics *)ucQueryMetrics {
    _ucQueryMetrics = ucQueryMetrics;
    [self addMetrics:ucQueryMetrics];
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

- (NSDictionary<NSString *, QNUploadRegionRequestMetrics *> *)syncCopyMetricsInfo {
    @synchronized (self) {
        return [_metricsInfo copy];
    }
}


@end
