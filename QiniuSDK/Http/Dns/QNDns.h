//
//  QNDns.h
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNInetAddressDelegate <NSObject>

/// 域名
@property(nonatomic,  copy, readonly)NSString *hostValue;

/// 地址IP信息
@property(nonatomic,  copy, readonly)NSString *ipValue;

/// ip有效时间 单位：秒
@property(nonatomic, strong, readonly)NSNumber *ttlValue;

/// 解析到host时的时间戳 单位：秒
@property(nonatomic, strong, readonly)NSNumber *timestampValue;

@end


@protocol QNDnsDelegate <NSObject>

/// 根据host获取解析结果
- (NSArray < id <QNInetAddressDelegate> > *)lookup:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
