//
//  QNIUploadServer.h
//  QiniuSDK
//
//  Created by yangsen on 2020/7/3.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import<Foundation/Foundation.h>

@protocol QNUploadServer <NSObject>

@property(nonatomic,  copy, nullable, readonly)NSString *httpVersion;
@property(nonatomic,  copy, nullable, readonly)NSString *serverId;
@property(nonatomic,  copy, nullable, readonly)NSString *ip;
@property(nonatomic,  copy, nullable, readonly)NSString *host;
@property(nonatomic,  copy, nullable, readonly)NSString *source;
@property(nonatomic,strong, nullable, readonly)NSNumber *ipPrefetchedTime;

@end

#define kQNHttpVersion1 @"http_version_1"
#define kQNHttpVersion2 @"http_version_2"
#define kQNHttpVersion3 @"http_version_3"

BOOL kQNIsHttp3(NSString * _Nullable httpVersion);
BOOL kQNIsHttp2(NSString * _Nullable httpVersion);


#define kQNDnsSourceDoh @"doh"
#define kQNDnsSourceUdp @"Udp"
#define kQNDnsSourceDnspod @"dnspod"
#define kQNDnsSourceSystem @"system"
#define kQNDnsSourceCustom @"custom"
#define kQNDnsSourceUnknown @"unknown"

BOOL kQNIsDnsSourceDoh(NSString * _Nullable source);
BOOL kQNIsDnsSourceUdp(NSString * _Nullable source);
BOOL kQNIsDnsSourceDnsPod(NSString * _Nullable source);
BOOL kQNIsDnsSourceSystem(NSString * _Nullable source);
BOOL kQNIsDnsSourceCustom(NSString * _Nullable source);
