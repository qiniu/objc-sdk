//
//  QNReportItem.h
//  QiniuSDK
//
//  Created by yangsen on 2020/5/12.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadInfoReporter.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNReportItem : NSObject

+ (instancetype)item;

/// 设置打点日志字段
- (void)setReportValue:(id _Nullable)value forKey:(NSString * _Nullable)key;
/// 移除打点日志字段
- (void)removeReportValueForKey:(NSString * _Nullable)key;

@end


@interface QNUploadInfoReporter(ReportItem)

- (void)reportItem:(QNReportItem *)item token:(NSString *)token;

@end


//MARK:-- 日志类型
extern NSString *const QNReportLogTypeRequest;
extern NSString *const QNReportLogTypeBlock;
extern NSString *const QNReportLogTypeQuality;


//MARK:-- 请求信息打点⽇志
extern NSString *const QNReportRequestKeyLogType;
extern NSString *const QNReportRequestKeyStatusCode;
extern NSString *const QNReportRequestKeyRequestId;
extern NSString *const QNReportRequestKeyHost;
extern NSString *const QNReportRequestKeyRemoteIp;
extern NSString *const QNReportRequestKeyPort;
extern NSString *const QNReportRequestKeyTargetBucket;
extern NSString *const QNReportRequestKeyTargetKey;
extern NSString *const QNReportRequestKeyTotalElaspsedTime;
extern NSString *const QNReportRequestKeyDnsElapsedTime;
extern NSString *const QNReportRequestKeyConnectElapsedTime;
extern NSString *const QNReportRequestKeyTLSConnectElapsedTime;
extern NSString *const QNReportRequestKeyRequestElapsedTime;
extern NSString *const QNReportRequestKeyWaitElapsedTime;
extern NSString *const QNReportRequestKeyResponseElapsedTime;
extern NSString *const QNReportRequestKeyFileOffset;
extern NSString *const QNReportRequestKeyBytesSent;
extern NSString *const QNReportRequestKeyBytesTotal;
extern NSString *const QNReportRequestKeyPid;
extern NSString *const QNReportRequestKeyTid;
extern NSString *const QNReportRequestKeyTargetRegionId;
extern NSString *const QNReportRequestKeyCurrentRegionId;
extern NSString *const QNReportRequestKeyErrorType;
extern NSString *const QNReportRequestKeyErrorDescription;
extern NSString *const QNReportRequestKeyUpType;
extern NSString *const QNReportRequestKeyOsName;
extern NSString *const QNReportRequestKeyOsVersion;
extern NSString *const QNReportRequestKeySDKName;
extern NSString *const QNReportRequestKeySDKVersion;
extern NSString *const QNReportRequestKeyClientTime;
extern NSString *const QNReportRequestKeyNetworkType;
extern NSString *const QNReportRequestKeySignalStrength;
extern NSString *const QNReportRequestKeyPrefetchedIpCount;


//MARK:-- 分块上传统计⽇志
extern NSString *const QNReportBlockKeyLogType;
extern NSString *const QNReportBlockKeyTargetRegionId;
extern NSString *const QNReportBlockKeyCurrentRegionId;
extern NSString *const QNReportBlockKeyTotalElaspsedTime;
extern NSString *const QNReportBlockKeyBytesSent;
extern NSString *const QNReportBlockKeyRecoveredFrom;
extern NSString *const QNReportBlockKeyFileSize;
extern NSString *const QNReportBlockKeyPid;
extern NSString *const QNReportBlockKeyTid;
extern NSString *const QNReportBlockKeyUpApiVersion;
extern NSString *const QNReportBlockKeyClient_time;


//MARK:-- 上传质量统计
extern NSString *const QNReportQualityKeyLogType;
extern NSString *const QNReportQualityKeyResult;
extern NSString *const QNReportQualityKeyTotalElaspsedTime;
extern NSString *const QNReportQualityKeyRequestsCount;
extern NSString *const QNReportQualityKeyRegionsCount;
extern NSString *const QNReportQualityKeyBytesSent;
extern NSString *const QNReportQualityKeyCloudType;


NS_ASSUME_NONNULL_END
