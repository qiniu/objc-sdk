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
@class QNDnsManager;
@class QNServiceAddress;
/**
 *    Builder block
 *
 *    @param builder builder实例
 */
typedef void (^QNConfigurationBuilderBlock)(QNConfigurationBuilder *builder);

@interface QNConfiguration : NSObject

/**
 *    默认上传服务器地址
 */
@property (copy, nonatomic, readonly) QNServiceAddress *up;

/**
 *    备用上传服务器地址
 */
@property (copy, nonatomic, readonly) QNServiceAddress *upBackup;

/**
 *    断点上传时的分片大小
 */
@property (readonly) UInt32 chunkSize;

/**
 *    如果大于此值就使用断点上传，否则使用form上传
 */
@property (readonly) UInt32 putThreshold;

/**
 *    上传失败的重试次数
 */
@property (readonly) UInt32 retryMax;

/**
 *    超时时间 单位 秒
 */
@property (readonly) UInt32 timeoutInterval;

@property (nonatomic, readonly) id<QNRecorderDelegate> recorder;

@property (nonatomic, readonly) QNRecorderKeyGenerator recorderKeyGen;

@property (nonatomic, readonly) NSDictionary *proxy;

@property (nonatomic, readonly) QNUrlConvert converter;

@property (nonatomic, readonly) QNDnsManager *dns;

@property (readonly) BOOL disableATS;

+ (instancetype)build:(QNConfigurationBuilderBlock)block;

@end

/**
 * 上传服务地址
 */
@interface QNServiceAddress : NSObject

- (instancetype)init:(NSString *)address ips:(NSArray *)ips;

@property (nonatomic, readonly) NSString *address;
@property (nonatomic, readonly) NSArray *ips;

@end

@interface QNZone : NSObject

/**
 *    默认上传服务器地址
 */
@property (nonatomic, readonly) QNServiceAddress *up;

/**
 *    备用上传服务器地址
 */
@property (nonatomic, readonly) QNServiceAddress *upBackup;

/**
 *    Zone初始化方法
 *
 *    @param upHost     默认上传服务器地址
 *    @param upHostBackup     备用上传服务器地址
 *    @param upIp       备用上传IP
 *
 *    @return Zone实例
 */
- (instancetype)initWithUp:(QNServiceAddress *)up
                  upBackup:(QNServiceAddress *)upBackup;

/**
 *    zone 0
 *
 *    @return 实例
 */
+ (instancetype)zone0;

/**
 *    zone 1
 *
 *    @return 实例
 */
+ (instancetype)zone1;

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
 *    上传失败的重试次数
 */
@property (assign) UInt32 retryMax;

/**
 *    超时时间 单位 秒
 */
@property (assign) UInt32 timeoutInterval;

@property (nonatomic, strong) id<QNRecorderDelegate> recorder;

@property (nonatomic, strong) QNRecorderKeyGenerator recorderKeyGen;

@property (nonatomic, strong) NSDictionary *proxy;

@property (nonatomic, strong) QNUrlConvert converter;

@property (nonatomic, strong) QNDnsManager *dns;

@property (assign) BOOL disableATS;

@end
