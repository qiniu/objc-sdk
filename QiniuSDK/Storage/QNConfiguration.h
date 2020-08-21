//
//  QNConfiguration.h
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNRecorderDelegate.h"
#import "QNDns.h"

/**
 * 断点上传时的分块大小
 */
extern const UInt32 kQNBlockSize;

/**
 *  DNS默认缓存时间
 */
extern const UInt32 kQNDefaultDnsCacheTime;

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
 *    上传失败时每个上传域名的重试次数，默认重试1次
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

/**
 *  重试时是否允许使用备用上传域名，默认为YES
 */
@property (nonatomic, assign) BOOL allowBackupHost;

/**
 *  持久化记录接口，可以实现将记录持久化到文件，数据库等
 */
@property (nonatomic, readonly) id<QNRecorderDelegate> recorder;

/**
 *  为持久化上传记录，根据上传的key以及文件名 生成持久化的记录key
 */
@property (nonatomic, readonly) QNRecorderKeyGenerator recorderKeyGen;

/**
 *  上传请求代理配置信息
 */
@property (nonatomic, readonly) NSDictionary *proxy;

/**
 *  上传URL转换，使url转换为用户需要的url
 */
@property (nonatomic, readonly) QNUrlConvert converter;

/**
 *  默认配置
 */
+ (instancetype)defaultConfiguration;

/**
 *  使用 QNConfigurationBuilder 进行配置
 *  @param block  配置block
 */
+ (instancetype)build:(QNConfigurationBuilderBlock)block;

@end


#define kQNGlobalConfiguration [QNGlobalConfiguration shared]
@interface QNGlobalConfiguration : NSObject

/**
 *   是否开启dns预解析 默认开启
 */
@property(nonatomic, assign)BOOL isDnsOpen;

/**
 *   dns 预取失败后 会进行重新预取  rePreHostNum为最多尝试次数
 */
@property(nonatomic, assign)UInt32 dnsRepreHostNum;

/**
 *   dns预取缓存时间  单位：秒
 */
@property(nonatomic, assign)UInt32 dnsCacheTime;

/**
 *   自定义DNS解析客户端host
 */
@property(nonatomic, strong) id <QNDnsDelegate> dns;

/**
 *   dns解析结果本地缓存路径
 */
@property(nonatomic,  copy, readonly)NSString *dnsCacheDir;

+ (instancetype)shared;

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
 *    上传失败时每个上传域名的重试次数，默认重试1次
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

/**
 *  持久化记录接口，可以实现将记录持久化到文件，数据库等
 */
@property (nonatomic, strong) id<QNRecorderDelegate> recorder;

/**
 *  为持久化上传记录，根据上传的key以及文件名 生成持久化的记录key
 */
@property (nonatomic, strong) QNRecorderKeyGenerator recorderKeyGen;

/**
 *  上传请求代理配置信息
 */
@property (nonatomic, strong) NSDictionary *proxy;

/**
 *  上传URL转换，使url转换为用户需要的url
 */
@property (nonatomic, strong) QNUrlConvert converter;

@end
