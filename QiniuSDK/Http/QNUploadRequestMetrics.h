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

@interface QNUploadMetrics : NSObject

@property (nonatomic, nullable, strong, readonly) NSDate *startDate;
@property (nonatomic, nullable, strong, readonly) NSDate *endDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalElapsedTime;

//MARK:-- 构造
+ (instancetype)emptyMetrics;

- (void)start;
- (void)end;

@end


@interface QNUploadSingleRequestMetrics : QNUploadMetrics

// 请求的 httpVersion
@property (nonatomic,  copy)NSString *httpVersion;

// 只有进行网络检测才会有 connectCheckMetrics
@property (nonatomic, nullable , strong) QNUploadSingleRequestMetrics *connectCheckMetrics;

// 错误信息
@property (nonatomic, nullable , strong) NSError *error;

@property (nonatomic, nullable, copy) NSURLRequest *request;
@property (nonatomic, nullable, copy) NSURLResponse *response;

@property (nonatomic, nullable, copy) NSDate *domainLookupStartDate;
@property (nonatomic, nullable, copy) NSDate *domainLookupEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalDnsTime;

@property (nonatomic, nullable, copy) NSDate *connectStartDate;
@property (nonatomic, nullable, copy) NSDate *connectEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalConnectTime;

@property (nonatomic, nullable, copy) NSDate *secureConnectionStartDate;
@property (nonatomic, nullable, copy) NSDate *secureConnectionEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalSecureConnectTime;

@property (nonatomic, nullable, copy) NSDate *requestStartDate;
@property (nonatomic, nullable, copy) NSDate *requestEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalRequestTime;

@property (nonatomic, nullable, strong, readonly) NSNumber *totalWaitTime;

@property (nonatomic, nullable, copy) NSDate *responseStartDate;
@property (nonatomic, nullable, copy) NSDate *responseEndDate;
@property (nonatomic, nullable, strong, readonly) NSNumber *totalResponseTime;

@property (nonatomic, assign) int64_t countOfRequestHeaderBytesSent;
@property (nonatomic, assign) int64_t countOfRequestBodyBytesSent;

@property (nonatomic, assign) int64_t countOfResponseHeaderBytesReceived;
@property (nonatomic, assign) int64_t countOfResponseBodyBytesReceived;

@property (nonatomic, nullable, copy) NSString *localAddress;
@property (nonatomic, nullable, copy) NSNumber *localPort;
@property (nonatomic, nullable, copy) NSString *remoteAddress;
@property (nonatomic, nullable, copy) NSNumber *remotePort;

@property (nonatomic, strong, readonly) NSNumber *totalBytes;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) NSNumber *perceptiveSpeed;


@end


@interface QNUploadRegionRequestMetrics : QNUploadMetrics

@property (nonatomic, strong, readonly) NSNumber *requestCount;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) id <QNUploadRegion> region;
@property (nonatomic,   copy, readonly) NSArray<QNUploadSingleRequestMetrics *> *metricsList;

//MARK:-- 构造
- (instancetype)initWithRegion:(id <QNUploadRegion>)region;

- (void)addMetricsList:(NSArray <QNUploadSingleRequestMetrics *> *)metricsList;
- (void)addMetrics:(QNUploadRegionRequestMetrics*)metrics;

@end


@interface QNUploadTaskMetrics : QNUploadMetrics

@property (nonatomic, strong, readonly) NSNumber *requestCount;
@property (nonatomic, strong, readonly) NSNumber *bytesSend;
@property (nonatomic, strong, readonly) NSNumber *regionCount;
@property (nonatomic, strong) NSArray<id <QNUploadRegion>> *regions;

- (void)addMetrics:(QNUploadRegionRequestMetrics *)metrics;

@end

NS_ASSUME_NONNULL_END
