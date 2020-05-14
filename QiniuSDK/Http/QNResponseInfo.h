//
//  QNResponseInfo.h
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadRequestMetrics.h"

/**
 *    中途取消的状态码
 */
extern const int kQNRequestCancelled;

/**
 *    网络错误状态码
 */
extern const int kQNNetworkError;

/**
 *    错误参数状态码
 */
extern const int kQNInvalidArgument;

/**
 *    0 字节文件或数据
 */
extern const int kQNZeroDataSize;

/**
 *    错误token状态码
 */
extern const int kQNInvalidToken;

/**
 *    读取文件错误状态码
 */
extern const int kQNFileError;

typedef NS_ENUM(int, QNResponseInfoErrorType){
    QNResponseInfoErrorTypeNetworkError = -1, // 未知⽹络错误
    QNResponseInfoErrorTypeUserCanceled = -2, // ⽤户主动取消
    QNResponseInfoErrorTypeInvalidArgs = -3, // 调⽤参数出错
    QNResponseInfoErrorTypeInvalidFile = -4, // ⽂件内容错误
    QNResponseInfoErrorTypeInvalidToken = -5, // token 无效
    QNResponseInfoErrorTypeZeroSizeFile = -6, // ⽂件⼤⼩错误
    
    QNResponseInfoErrorTypeProxyError = -200, // 当前使⽤了 HTTP Proxy 且 Proxy 出错
    
    QNResponseInfoErrorTypeUnexpectedSyscallError, // ⾮预期的，⽆法解决的系统调⽤错误（例如内存分配错误，线程创建错误等因为资源不⾜⽽造成的错误）
    QNResponseInfoErrorTypeLocalIoError, // 本地 I/O 错误
    QNResponseInfoErrorTypeNetworkSlow, // ⽹速过低或没有⽹络造成上传失败的
    
    QNResponseInfoErrorTypeSystemCanceled = -999, // ⽤户主动取消
    QNResponseInfoErrorTypeSystemNetworkError = -1009, // 未知⽹络错误
    QNResponseInfoErrorTypeTimeout = -1001, // 超时错误
    QNResponseInfoErrorTypeUnknownHost, // DNS 解析错误
    QNResponseInfoErrorTypeCannotConnectToHost = -1004, // 连接服务器错误
    QNResponseInfoErrorTypeConnectionLost = -1005, // 传输错误
    QNResponseInfoErrorTypeBadServerResponse = -1011, // 传输错误
    QNResponseInfoErrorTypeSSLHandShakeError = -9807, // SSL握手错误
    QNResponseInfoErrorTypeSSLError = -2001, // 加密错误
    QNResponseInfoErrorTypeCannotDecodeRawData = -1015, // 解析响应错误
    QNResponseInfoErrorTypeCannotDecodeContentData = -1016, // 解析响应错误
    QNResponseInfoErrorTypeCannotParseResponse = -1017, // 解析响应错误
    QNResponseInfoErrorTypeTooManyRedirects = -1007, // ⽤户劫持错误
    QNResponseInfoErrorTypeRedirectToNonExistentLocation = -1010, // ⽤户劫持错误
    
    QNResponseInfoErrorTypeUnknownError = -500, // 未知错误
};

/**
 *    上传完成后返回的状态信息
 */
@interface QNResponseInfo : NSObject

/// 状态码
@property (readonly) int statusCode;
/// response 信息
@property (nonatomic, copy, readonly) NSDictionary *responseDictionary;
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
/// 请求过程统计信息
@property(nonatomic, strong) QNUploadSingleRequestMetrics *requestMetrics;
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
/// 是否为 七牛响应
@property (nonatomic, readonly, getter=isNotQiniu) BOOL notQiniu;

//MARK:-- 构造函数
+ (instancetype)cancelResponse;
+ (instancetype)responseInfoWithNetworkError:(NSString *)desc;
+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc;
+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc;
+ (instancetype)responseInfoWithFileError:(NSError *)error;
+ (instancetype)responseInfoOfZeroData:(NSString *)path;

+ (instancetype)errorResponseInfo:(QNResponseInfoErrorType)errorType
                        errorDesc:(NSString *)errorDesc;
- (instancetype)initWithResponseInfoHost:(NSString *)host
                                response:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error;
@end
