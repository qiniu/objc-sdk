//
//  QNResponseInfo.h
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadRequestMetrics.h"

@class QNHttpResponseInfo;

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
    QNResponseInfoErrorTypeUnknownError = -200, // 未知错误
    QNResponseInfoErrorTypeProxyError, // 当前使⽤了 HTTP Proxy 且 Proxy 出错
    QNResponseInfoErrorTypeInvalidToken, // token 无效

    QNResponseInfoErrorTypeZeroSizeFile, // ⽂件⼤⼩错误
    QNResponseInfoErrorTypeInvalidFile, // ⽂件内容错误
    QNResponseInfoErrorTypeInvalidArgs, // 调⽤参数出错
    QNResponseInfoErrorTypeUnexpectedSyscallError, // ⾮预期的，⽆法解决的系统调⽤错误（例如内存分配错误，线程创建错误等因为资源不⾜⽽造成的错误）
    QNResponseInfoErrorTypeLocalIoError, // 本地 I/O 错误
    QNResponseInfoErrorTypeNetworkSlow, // ⽹速过低或没有⽹络造成上传失败的
    
    QNResponseInfoErrorTypeNetworkError = -1009, // 未知⽹络错误
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
    QNResponseInfoErrorTypeUserCanceled = -999, // ⽤户主动取消
};

/**
 *    上传完成后返回的状态信息
 */
@interface QNResponseInfo : NSObject

/**
 *    状态码
 */
@property (readonly) int statusCode;

/**
 *    response message
 */
@property (nonatomic, copy, readonly) NSString *msg;

/**
 *    response message
 */
@property (nonatomic, copy, readonly) NSString *msgDetail;

/**
 *    七牛服务器生成的请求ID，用来跟踪请求信息，如果使用过程中出现问题，请反馈此ID
 */
@property (nonatomic, copy, readonly) NSString *reqId;

/**
 *    七牛服务器内部跟踪记录
 */
@property (nonatomic, copy, readonly) NSString *xlog;

/**
 *    cdn服务器内部跟踪记录
 */
@property (nonatomic, copy, readonly) NSString *xvia;

/**
 *    错误信息，出错时请反馈此记录
 */
@property (nonatomic, copy, readonly) NSError *error;

/**
 *    服务器域名
 */
@property (nonatomic, copy, readonly) NSString *host;

/**
 *    客户端id
 */
@property (nonatomic, readonly) NSString *id;

/**
 *    时间戳
 */
@property (readonly) UInt64 timeStamp;

/// 请求过程统计信息
@property(nonatomic, strong)QNUploadSingleRequestMetrics *requestMetrics;

/**
 *    是否取消
 */
@property (nonatomic, readonly, getter=isCancelled) BOOL canceled;

/**
 *    成功的请求
 */
@property (nonatomic, readonly, getter=isOK) BOOL ok;

/**
 *    是否网络错误
 */
@property (nonatomic, readonly, getter=isConnectionBroken) BOOL broken;

/**
 *    是否TLS错误
 */
@property (nonatomic, readonly) BOOL isTlsError;

/**
 *    是否可以再次重试，当遇到权限等怎么重试都不可能成功的问题时，返回NO
 */
@property (nonatomic, readonly) BOOL couldRetry;

/**
 *    单个host是否可以再次重试
 */
@property (nonatomic, readonly) BOOL couldHostRetry;

/**
 *    单个Region是否可以再次重试
 */
@property (nonatomic, readonly) BOOL couldRegionRetry;

/**
 *    是否为 七牛响应
 */
@property (nonatomic, readonly, getter=isNotQiniu) BOOL notQiniu;

/**
 *    工厂函数，内部使用
 *    @return 取消的实例
 */
+ (instancetype)cancelResponse;

/**
 *    工厂函数，内部使用
 *    @param desc 错误参数描述
 *    @return 错误参数实例
 */
+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc;

/**
 *    工厂函数，内部使用
 *    @param desc 错误token描述
 *    @return 错误token实例
 */
+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc;

/**
 *    工厂函数，内部使用
 *    @param error 错误信息
 *    @return 文件错误实例
 */
+ (instancetype)responseInfoWithFileError:(NSError *)error;

/**
 *    工厂函数，内部使用
 *    @param path        文件路径
 *    @return 文件错误实例
 */
+ (instancetype)responseInfoOfZeroData:(NSString *)path;

/**
 *    工厂函数，内部使用
 *    @param errorType      错误类型
 *    @param errorDesc      错误详细描述 会被记录在msgDetail里
 *    @return 文件错误实例
 */
+ (instancetype)errorResponseInfo:(QNResponseInfoErrorType)errorType
                        errorDesc:(NSString *)errorDesc;

/**
 *    工厂函数，内部使用
 *
 *    @param httpResponseInfo   最后一次http请求的信息
 *    @param duration   请求完成时间，单位秒
 *
 *    @return 实例
 */
+ (instancetype)responseInfoWithHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo
                                        duration:(double)duration;

- (instancetype)initWithResponseInfoHost:(NSString *)host
                                response:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error;
@end
