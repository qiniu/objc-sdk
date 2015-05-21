//
//  QNConfiguration.h
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNConfiguration : NSObject

@end


@interface QNZone : NSObject

/**
 *    默认上传服务器地址
 */
@property (copy, nonatomic, readonly) NSString *upHost;

/**
 *    备用上传服务器地址
 */
@property (copy, nonatomic, readonly) NSString *upHostBackup;

/**
 *    备用上传IP
 */
@property (copy, nonatomic, readonly) NSString *upIp;

/**
 *    Zone初始化方法
 *
 *    @param upHost     默认上传服务器地址
 *    @param upHostBackup     备用上传服务器地址
 *    @param upIp       备用上传IP
 *
 *    @return Zone实例
 */
- (instancetype)initWithUpHost:(NSString *)upHost
             upHostBackup:(NSString *)upHostBackup
                      upIp:(NSString *)upIp;

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
