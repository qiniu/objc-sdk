//
//  QNServerConfig.h
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNServerRegionConfig : NSObject

@property(nonatomic, assign, readonly)long clearId;
@property(nonatomic, assign, readonly)BOOL clearCache;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface QNServerDnsServer : NSObject

@property(nonatomic, assign, readonly)BOOL isOverride;
@property(nonatomic, strong, readonly)NSArray <NSString *> *servers;

+ (instancetype)config:(NSDictionary *)info;

@end

@interface QNServerDohConfig : NSObject

@property(nonatomic, strong, readonly)NSNumber *enable;
@property(nonatomic, strong, readonly)QNServerDnsServer *ipv4Server;
@property(nonatomic, strong, readonly)QNServerDnsServer *ipv6Server;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface QNServerUdpDnsConfig : NSObject

@property(nonatomic, strong, readonly)NSNumber *enable;
@property(nonatomic, strong, readonly)QNServerDnsServer *ipv4Server;
@property(nonatomic, strong, readonly)QNServerDnsServer *ipv6Server;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface QNServerDnsConfig : NSObject

@property(nonatomic, strong, readonly)NSNumber *enable;
@property(nonatomic, assign, readonly)long clearId;
@property(nonatomic, assign, readonly)BOOL clearCache;
@property(nonatomic, strong, readonly)QNServerUdpDnsConfig *udpConfig;
@property(nonatomic, strong, readonly)QNServerDohConfig *dohConfig;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface QNServerConfig : NSObject

@property(nonatomic, assign, readonly)BOOL isValid;
@property(nonatomic, assign, readonly)long ttl;
@property(nonatomic, strong, readonly)QNServerRegionConfig *regionConfig;
@property(nonatomic, strong, readonly)QNServerDnsConfig *dnsConfig;

@property(nonatomic, strong, readonly)NSDictionary *info;

+ (instancetype)config:(NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
