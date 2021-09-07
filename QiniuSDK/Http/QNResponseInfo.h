//
//  QNResponseInfo.h
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNErrorCode.h"

/**
 *    上传完成后返回的状态信息
 */
@interface QNResponseInfo : NSObject

/// 状态码
@property (readonly) int statusCode;
/// response 信息
@property (nonatomic, copy, readonly) NSDictionary *responseDictionary;
/// response 头信息
@property (nonatomic, copy, readonly) NSDictionary *responseHeader;
/// response message
@property (nonatomic, copy, readonly) NSString *message;
/// 七牛服务器生成的请求ID，用来跟踪请求信息，如果使用过程中出现问题，请反馈此ID
@property (nonatomic, copy, readonly) NSString *reqId;
/// 七牛服务器内部跟踪记录
@property (nonatomic, copy, readonly) NSString *xlog;
/// cdn服务器内部跟踪记录
@property (nonatomic, copy, readonly) NSString *xvia;
/// 错误信息，出错时请反馈此记录
@property (nonatomic, copy, readonly) NSError *error;
/// 服务器域名
@property (nonatomic, copy, readonly) NSString *host;
/// 客户端id
@property (nonatomic, readonly) NSString *id;
/// 时间戳
@property (readonly) UInt64 timeStamp;
/// 是否取消
@property (nonatomic, readonly, getter=isCancelled) BOOL canceled;
/// 成功的请求
@property (nonatomic, readonly, getter=isOK) BOOL ok;
/// 是否网络错误
@property (nonatomic, readonly, getter=isConnectionBroken) BOOL broken;
/// 是否TLS错误
@property (nonatomic, readonly) BOOL isTlsError;
/// 是否可以再次重试，当遇到权限等怎么重试都不可能成功的问题时，返回NO
@property (nonatomic, readonly) BOOL couldRetry;
/// 单个host是否可以再次重试
@property (nonatomic, readonly) BOOL couldHostRetry;
/// 单个Region是否可以再次重试
@property (nonatomic, readonly) BOOL couldRegionRetry;
/// 当前host是否可达
@property (nonatomic, readonly) BOOL canConnectToHost;
/// 当前host是否可用
@property (nonatomic, readonly) BOOL isHostUnavailable;
/// 是否为 七牛响应
@property (nonatomic, readonly, getter=isNotQiniu) BOOL notQiniu;

//MARK:-- 构造函数 【内部使用】
+ (instancetype)successResponse;
+ (instancetype)cancelResponse;
+ (instancetype)responseInfoWithNetworkError:(NSString *)desc;
+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc;
+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc;
+ (instancetype)responseInfoWithFileError:(NSError *)error;
+ (instancetype)responseInfoOfZeroData:(NSString *)path;
+ (instancetype)responseInfoWithLocalIOError:(NSString *)desc;
+ (instancetype)responseInfoWithMaliciousResponseError:(NSString *)desc;
// 使用responseInfoWithSDKInteriorError替代
+ (instancetype)responseInfoWithNoUsableHostError:(NSString *)desc NS_UNAVAILABLE;
+ (instancetype)responseInfoWithSDKInteriorError:(NSString *)desc;
+ (instancetype)responseInfoWithUnexpectedSysCallError:(NSString *)desc;

+ (instancetype)errorResponseInfo:(int)errorType
                        errorDesc:(NSString *)errorDesc;
- (instancetype)initWithResponseInfoHost:(NSString *)host
                                response:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error;
@end
