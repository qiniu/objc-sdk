//
//  QNConfiguration.h
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNRecorderDelegate.h"

/**
 *    断点上传时的分块大小
 */
extern const UInt32 kQNBlockSize;

/**
 *    转换为用户需要的url
 *
 *    @param url  上传url
 *
 *    @return 根据上传url算出代理url
 */
typedef NSString * (^QNUrlConvert)(NSString *url);

@class QNConfigurationBuilder;
@class QNZone;
@class QNReportConfig;
@class QNReportRequestItem;
/**
 *    Builder block
 *
 *    @param builder builder实例
 */
typedef void (^QNConfigurationBuilderBlock)(QNConfigurationBuilder *builder);

@interface QNConfiguration : NSObject

/**
 *    存储区域
 */
@property (copy, nonatomic, readonly) QNZone *zone;

/**
 *    断点上传时的分片大小
 */
@property (readonly) UInt32 chunkSize;

/**
 *    如果大于此值就使用断点上传，否则使用form上传
 */
@property (readonly) UInt32 putThreshold;

/**
 *    上传失败时每个上传域名的重试次数，默认重试3次
 */
@property (readonly) UInt32 retryMax;

/**
 *    重试前等待时长，默认0.5s
 */
@property (readonly) NSTimeInterval retryInterval;

/**
 *    超时时间 单位 秒
 */
@property (readonly) UInt32 timeoutInterval;

/**
 *    是否使用 https，默认为 YES
 */
@property (nonatomic, assign, readonly) BOOL useHttps;

/**
  *   是否开启并发分片上传，默认为NO
  */
@property (nonatomic, assign, readonly) BOOL useConcurrentResumeUpload;

/**
 *   并发分片上传的并发任务个数，在concurrentResumeUpload为YES时有效，默认为3个
 */
@property (nonatomic, assign, readonly) UInt32 concurrentTaskCount;

@property (nonatomic, readonly) QNReportConfig *reportConfig;

/**
 *    重试时是否允许使用备用上传域名，默认为YES
 */
@property (nonatomic, assign) BOOL allowBackupHost;

@property (nonatomic, readonly) id<QNRecorderDelegate> recorder;

@property (nonatomic, readonly) QNRecorderKeyGenerator recorderKeyGen;

@property (nonatomic, readonly) NSDictionary *proxy;

@property (nonatomic, readonly) QNUrlConvert converter;

+ (instancetype)build:(QNConfigurationBuilderBlock)block;

@end

typedef void (^QNPrequeryReturn)(int code, QNReportRequestItem *item);
typedef NS_ENUM(NSUInteger, QNZoneInfoType) {
    QNZoneInfoTypeMain,
    QNZoneInfoTypeBackup,
};

@class QNUpToken;
@class QNBaseZoneInfo;

@interface QNZonesInfo : NSObject

@property (readonly, nonatomic) NSArray<QNBaseZoneInfo *> *zonesInfo;

@property (readonly, nonatomic) BOOL hasBackupZone;

- (NSString *)getZoneInfoRegionNameWithType:(QNZoneInfoType)type;

@end

@interface QNZone : NSObject

/**
 *    默认上传服务器地址列表
 */
- (void)preQueryWithToken:(QNUpToken *)token
                      key:(NSString *)key
                       on:(QNPrequeryReturn)ret;

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token;

- (NSString *)up:(QNUpToken *)token
zoneInfoType:(QNZoneInfoType)zoneInfoType
         isHttps:(BOOL)isHttps
    frozenDomain:(NSString *)frozenDomain;

@end

@interface QNFixedZone : QNZone

/**
 *    zone 0 华东
 *
 *    @return 实例
 */
+ (instancetype)zone0;

/**
 *    zone 1 华北
 *
 *    @return 实例
 */
+ (instancetype)zone1;

/**
 *    zone 2 华南
 *
 *    @return 实例
 */
+ (instancetype)zone2;

/**
 *    zone Na0 北美
 *
 *    @return 实例
 */
+ (instancetype)zoneNa0;

/**
 *    zone As0 新加坡
 *
 *    @return 实例
*/
+ (instancetype)zoneAs0;

/**
 *    Zone初始化方法
 *
 *    @param upList     默认上传服务器地址列表
 *
 *    @return Zone实例
 */
- (instancetype)initWithupDomainList:(NSArray<NSString *> *)upList;

@end

@interface QNAutoZone : QNZone
 
@end

@interface QNConfigurationBuilder : NSObject

/**
 *    默认上传服务器地址
 */
@property (nonatomic, strong) QNZone *zone;

/**
 *    断点上传时的分片大小
 */
@property (assign) UInt32 chunkSize;

/**
 *    如果大于此值就使用断点上传，否则使用form上传
 */
@property (assign) UInt32 putThreshold;

/**
 *    上传失败时每个上传域名的重试次数，默认重试3次
 */
@property (assign) UInt32 retryMax;

/**
 *    重试前等待时长，默认0.5s
 */
@property (assign) NSTimeInterval retryInterval;

/**
 *    超时时间 单位 秒
 */
@property (assign) UInt32 timeoutInterval;

/**
 *    是否使用 https，默认为 YES
 */
@property (nonatomic, assign) BOOL useHttps;

/**
 *    重试时是否允许使用备用上传域名，默认为YES
 */
@property (nonatomic, assign) BOOL allowBackupHost;

/**
 *   是否开启并发分片上传，默认为NO
 */
@property (nonatomic, assign) BOOL useConcurrentResumeUpload;

/**
 *   并发分片上传的并发任务个数，在concurrentResumeUpload为YES时有效，默认为3个
 */
@property (nonatomic, assign) UInt32 concurrentTaskCount;

@property (nonatomic, strong) id<QNRecorderDelegate> recorder;

@property (nonatomic, strong) QNRecorderKeyGenerator recorderKeyGen;

@property (nonatomic, strong) QNReportConfig *reportConfig;

@property (nonatomic, strong) NSDictionary *proxy;

@property (nonatomic, strong) QNUrlConvert converter;

@end
