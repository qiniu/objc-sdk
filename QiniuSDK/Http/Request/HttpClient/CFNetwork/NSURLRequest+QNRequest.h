//
//  NSURLRequest+QNRequest.h
//  AppTest
//
//  Created by yangsen on 2020/4/8.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest(QNRequest)

/// 是否是七牛请求【内部使用】
/// 作为是否进行请求监听的判断依据 NO，当设置了qn_domain返回YES，反之为NO
@property(nonatomic, assign, readonly)BOOL qn_isQiNiuRequest;

/// 请求id【内部使用】
/// 只有通过设置qn_domain才会有效
@property(nonatomic, strong, nullable, readonly)NSString *qn_identifier;

/// 请求domain【内部使用】
/// 只有通过NSMutableURLRequest设置才会有效
@property(nonatomic, strong, nullable, readonly)NSString *qn_domain;

/// 请求ip【内部使用】
/// 只有通过NSMutableURLRequest设置才会有效
@property(nonatomic, strong, nullable, readonly)NSString *qn_ip;

/// 请求头信息 去除七牛内部标记占位
@property(nonatomic, strong, nullable, readonly)NSDictionary *qn_allHTTPHeaderFields;

+ (instancetype)qn_requestWithURL:(NSURL *)url;

/// 获取请求体
- (NSData *)qn_getHttpBody;

- (BOOL)qn_isHttps;

@end


@interface NSMutableURLRequest(QNRequest)

/// 请求domain【内部使用】
@property(nonatomic, strong, nullable)NSString *qn_domain;
/// 请求ip【内部使用】
@property(nonatomic, strong, nullable)NSString *qn_ip;

@end

NS_ASSUME_NONNULL_END

