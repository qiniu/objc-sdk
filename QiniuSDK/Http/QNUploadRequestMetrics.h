//
//  QNUploadRequestMetrics.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadSingleRequestMetrics : NSObject

@property (copy) NSURLRequest *request;
@property (nullable, copy) NSURLResponse *response;

@property (nullable, copy) NSDate *startDate;
@property (nullable, copy) NSDate *endDate;
@property (nonatomic, strong, readonly) NSNumber *totalElaspsedTime;

@property (nullable, copy) NSDate *domainLookupStartDate;
@property (nullable, copy) NSDate *domainLookupEndDate;
@property (nonatomic, strong, readonly) NSNumber *totalDnsTime;

@property (nullable, copy) NSDate *connectStartDate;
@property (nullable, copy) NSDate *connectEndDate;
@property (nonatomic, strong, readonly) NSNumber *totalConnectTime;

@property (nullable, copy) NSDate *secureConnectionStartDate;
@property (nullable, copy) NSDate *secureConnectionEndDate;
@property (nonatomic, strong, readonly) NSNumber *totalSecureConnectTime;

@property (nullable, copy) NSDate *requestStartDate;
@property (nullable, copy) NSDate *requestEndDate;
@property (nonatomic, strong, readonly) NSNumber *totalRequestTime;

@property (nonatomic, strong, readonly) NSNumber *totalWaitTime;

@property (nullable, copy) NSDate *responseStartDate;
@property (nullable, copy) NSDate *responseEndDate;
@property (nonatomic, strong, readonly) NSNumber *totalResponseTime;

@property (assign) int64_t countOfRequestHeaderBytesSent;
@property (assign) int64_t countOfRequestBodyBytesSent;

@property (assign) int64_t countOfResponseHeaderBytesReceived;
@property (assign) int64_t countOfResponseBodyBytesReceived;

@property (nullable, copy) NSString *localAddress;
@property (nullable, copy) NSNumber *localPort;
@property (nullable, copy) NSString *remoteAddress;
@property (nullable, copy) NSNumber *remotePort;

@property (nonatomic, strong, readonly) NSNumber *totalBytes;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;

//MARK:-- 构造
+ (instancetype)emptyMetrics;

@end


@interface QNUploadRegionRequestMetrics : NSObject

@property (nonatomic, strong, readonly) NSNumber *totalElaspsedTime;
@property (nonatomic, strong, readonly) NSNumber *requestCount;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) id <QNUploadRegion> region;
@property (nonatomic,   copy, readonly) NSArray<QNUploadSingleRequestMetrics *> *metricsList;

//MARK:-- 构造
+ (instancetype)emptyMetrics;
- (instancetype)initWithRegion:(id <QNUploadRegion>)region;

- (void)addMetricsList:(NSArray <QNUploadSingleRequestMetrics *> *)metricsList;

@end


@interface QNUploadTaskMetrics : NSObject

@property (nonatomic, strong, readonly) NSNumber *totalElaspsedTime;
@property (nonatomic, strong, readonly) NSNumber *requestCount;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) NSNumber *regionCount;
@property (nonatomic, strong, readonly) NSArray<id <QNUploadRegion>> *regions;
@property (nonatomic,   copy, readonly) NSArray<QNUploadRegionRequestMetrics *> *metricsList;

//MARK:-- 构造
+ (instancetype)emptyMetrics;
- (instancetype)initWithRegions:(NSArray<id <QNUploadRegion>> *)regions;

- (void)addMetrics:(QNUploadRegionRequestMetrics *)metrics;

@end

NS_ASSUME_NONNULL_END
