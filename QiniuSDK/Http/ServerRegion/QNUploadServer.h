//
//  QNUploadServer.h
//  AppTest
//
//  Created by yangsen on 2020/4/23.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadServer : NSObject <QNUploadServer>

/// 上传server构造方法
/// @param serverId server标识，一般使用host
/// @param host host
/// @param ip host对应的IP
/// @param source ip查询来源，@"system"，@"httpdns"， @"none"， @"customized" 自定义请使用@"customized"
/// @param ipPrefetchedTime 根据host获取IP的时间戳
+ (instancetype)server:(NSString * _Nullable)serverId
                  host:(NSString * _Nullable)host
                    ip:(NSString * _Nullable)ip
                source:(NSString * _Nullable)source
      ipPrefetchedTime:(NSNumber * _Nullable)ipPrefetchedTime;

@end

NS_ASSUME_NONNULL_END
