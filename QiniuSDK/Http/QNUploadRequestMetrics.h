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

@property (nullable, copy) NSDate *fetchStartDate;
@property (nullable, copy) NSDate *domainLookupStartDate;
@property (nullable, copy) NSDate *domainLookupEndDate;
@property (nullable, copy) NSDate *connectStartDate;
@property (nullable, copy) NSDate *secureConnectionStartDate;
@property (nullable, copy) NSDate *secureConnectionEndDate;
@property (nullable, copy) NSDate *connectEndDate;

@property (nullable, copy) NSDate *requestStartDate;
@property (nullable, copy) NSDate *requestEndDate;
@property (nullable, copy) NSDate *responseStartDate;
@property (nullable, copy) NSDate *responseEndDate;

@property (assign) int64_t countOfRequestHeaderBytesSent;
@property (assign) int64_t countOfRequestBodyBytesSent;

@property (assign) int64_t countOfResponseHeaderBytesReceived;
@property (assign) int64_t countOfResponseBodyBytesReceived;

@property (nullable, copy) NSString *localAddress;
@property (nullable, copy) NSNumber *localPort;
@property (nullable, copy) NSString *remoteAddress;
@property (nullable, copy) NSNumber *remotePort;

@end


@interface QNUploadRegionRequestMetrics : NSObject

@property (nonatomic, strong, readonly) id <QNUploadRegion> region;
@property (nonatomic,   copy, readonly) NSArray<QNUploadSingleRequestMetrics *> *metricsList;

- (instancetype)initWithRegion:(id <QNUploadRegion>)region;

- (void)addMetrics:(QNUploadSingleRequestMetrics *)metrics;

@end


@interface QNUploadTaskMetrics : NSObject

@property (nonatomic, strong, readonly) NSArray<id <QNUploadRegion>> *regions;
@property (nonatomic,   copy, readonly) NSArray<QNUploadRegionRequestMetrics *> *metricsList;

- (instancetype)initWithRegions:(NSArray<id <QNUploadRegion>> *)regions;

- (void)addMetrics:(QNUploadSingleRequestMetrics *)metrics;

@end

NS_ASSUME_NONNULL_END
