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


@interface QNServerDohConfig : NSObject

@property(nonatomic, assign, readonly)NSNumber *enable;
@property(nonatomic,   copy, readonly)NSArray <NSString *> *ipv4Server;
@property(nonatomic,   copy, readonly)NSArray <NSString *> *ipv6Server;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface QNServerUdpDnsConfig : NSObject

@property(nonatomic, assign, readonly)NSNumber *enable;
@property(nonatomic,   copy, readonly)NSArray <NSString *> *ipv4Server;
@property(nonatomic,   copy, readonly)NSArray <NSString *> *ipv6Server;

+ (instancetype)config:(NSDictionary *)info;

@end


@interface QNServerDnsConfig : NSObject

@property(nonatomic, assign, readonly)NSNumber *enable;
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
