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

typedef NS_ENUM(NSInteger, QNResumeUploadVersion){
    QNResumeUploadVersionV1, // 分片v1
    QNResumeUploadVersionV2  // 分片v2
};

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
 *    单个请求超时时间 单位 秒
 *    注：每个文件上传肯能存在多个操作，当每个操作失败时，可能存在多个请求重试。
 */
@property (readonly) UInt32 timeoutInterval;

/**
 *    是否使用 https，默认为 YES
 */
@property (nonatomic, assign, readonly) BOOL useHttps;

/**
 *   单个文件是否开启并发分片上传，默认为NO
 *   单个文件大小大于4M时，会采用分片上传，每个分片会已单独的请求进行上传操作，多个上传操作可以使用并发，
 *   也可以采用串行，采用并发时，可以设置并发的个数(对concurrentTaskCount进行设置)。
 */
@property (nonatomic, assign, readonly) BOOL useConcurrentResumeUpload;

/**
 *   分片上传版本
 */
@property (nonatomic, assign, readonly) QNResumeUploadVersion resumeUploadVersion;

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
 *   dns 预取失败后 会进行重新预取  dnsRepreHostNum为最多尝试次数
 */
@property(nonatomic, assign)UInt32 dnsRepreHostNum;

/**
 *   dns 预取, ip 默认有效时间  单位：秒 默认：120
 *   只有在 dns 预取未返回 ttl 时使用
 */
@property(nonatomic, assign)UInt32 dnsCacheTime;

/**
 *   dns预取缓存最大有效时间  单位：秒 默认 1800
 *   当 dns 缓存 ip 过期并未刷新时，只要在 dnsCacheMaxTTL 时间内仍有效。
 */
@property(nonatomic, assign)UInt32 dnsCacheMaxTTL;

/**
 *   自定义DNS解析客户端host
 */
@property(nonatomic, strong) id <QNDnsDelegate> dns;

/**
 *   dns解析结果本地缓存路径
 */
@property(nonatomic,  copy, readonly)NSString *dnsCacheDir;

/**
 *   Host全局冻结时间  单位：秒   默认：10  推荐范围：[5 ~ 30]
 *   当某个Host的上传失败后并且可能短时间无法恢复，会冻结该Host
 */
@property(nonatomic, assign)UInt32 globalHostFrozenTime;

/**
 *   Host局部冻结时间，只会影响当前上传操作  单位：秒   默认：5*60  推荐范围：[60 ~ 10*60]
 *   当某个Host的上传失败后并且短时间可能会恢复，会局部冻结该Host
 */
@property(nonatomic, assign)UInt32 partialHostFrozenTime;

/**
 *  网络连接状态检测使用的connectCheckURLStrings，网络链接状态检测可能会影响重试机制，启动网络连接状态检测有助于提高上传可用性。
 *  当请求的 Response 为网络异常时，并发对 connectCheckURLStrings 中 URLString 进行 HEAD 请求，以此检测当前网络状态的链接状态，其中任意一个 URLString 链接成功则认为当前网络状态链接良好；
 *  当 connectCheckURLStrings 为 nil 或者 空数组时则弃用检测功能。
 */
@property(nonatomic, strong)NSArray <NSString *> *connectCheckURLStrings;

/**
 *  是否开启网络连接状态检测，默认：开启
 */
@property(nonatomic, assign)BOOL connectCheckEnable;

/**
 *  网络连接状态检测HEAD请求超时，默认：2s
 */
@property(nonatomic, assign)NSTimeInterval connectCheckTimeout;


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
 *   分片上传版本
 */
@property (nonatomic, assign) QNResumeUploadVersion resumeUploadVersion;

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
