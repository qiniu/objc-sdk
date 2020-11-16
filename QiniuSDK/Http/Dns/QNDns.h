//
//  QNDns.h
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNIDnsNetworkAddress <NSObject>

/// 域名
@property(nonatomic,  copy, readonly)NSString *hostValue;

/// 地址IP信息
@property(nonatomic,  copy, readonly)NSString *ipValue;

/// ip有效时间 单位：秒
@property(nonatomic, strong, readonly)NSNumber *ttlValue;

/// ip预取来源, 自定义dns返回 @"customized"
@property(nonatomic,  copy, readonly)NSString *sourceValue;

/// 解析到host时的时间戳 单位：秒
@property(nonatomic, strong, readonly)NSNumber *timestampValue;

@end


@protocol QNDnsDelegate <NSObject>

/// 根据host获取解析结果
/// @param host 域名
- (NSArray < id <QNIDnsNetworkAddress> > *)lookup:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
