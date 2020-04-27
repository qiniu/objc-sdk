//
//  QNUploadInfoCollector.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define Collector [QNUploadInfoCollector sharedInstance]

@class QNHttpResponseInfo;
@class QNResponseInfo;

// request types
typedef enum : NSUInteger {
    QNRequestType_form,
    QNRequestType_mkblk,
    QNRequestType_bput,
    QNRequestType_mkfile,
    QNRequestType_put,
    QNRequestType_initParts,
    QNRequestType_uploadParts,
    QNRequestType_completeParts,
    QNRequestType_ucQuery,
    QNRequestType_httpdnsQuery
} QNRequestType;

typedef NSString QNCollectKey;

// update key
extern QNCollectKey *const CK_bucket;
extern QNCollectKey *const CK_key;
extern QNCollectKey *const CK_targetRegionId;
extern QNCollectKey *const CK_currentRegionId;
extern QNCollectKey *const CK_result;
extern QNCollectKey *const CK_recoveredFrom;
extern QNCollectKey *const CK_fileSize;
extern QNCollectKey *const CK_blockApiVersion;

// append key
extern QNCollectKey *const CK_blockBytesSent;
extern QNCollectKey *const CK_totalBytesSent;

// Upload Result Type
extern NSString *const upload_ok;   // 上传成功
extern NSString *const zero_size_file;  // ⽂件⼤小错误
extern NSString *const invalid_file;  // 文件内容错误
extern NSString *const invalid_args; // 调用参数出错
extern NSString *const local_io_error; // 本地 I/O 错误

/// Network Error Type
extern NSString *const unknown_error;   // 未知错误
extern NSString *const network_error; // 未知网络错误
extern NSString *const network_timeout;   // 超时错误
extern NSString *const unknown_host;    // DNS 解析错误
extern NSString *const cannot_connect_to_host;  // 连接服务器器错误
extern NSString *const transmission_error;  // 传输错误
extern NSString *const proxy_error;     // 使用了 HTTP Proxy 且 Proxy 出错
extern NSString *const ssl_error;    // SSL 加密错误
extern NSString *const response_error;  // 收到响应，但状态码非 200
extern NSString *const parse_error;  // 解析响应错误
extern NSString *const malicious_response;   // 用户劫持错误
extern NSString *const user_canceled;   // 用户主动取消
extern NSString *const bad_request;   // API 失败是由于客户端的参数错误导致，⽆法依靠重试来解决的(例如 4xx 错误， upload token 错误，⽬标 bucket 不存在，⽂件已经存在，区域不正确，额度不够 等)

extern int64_t QN_IntNotSet;

// 用于统计上传质量 和生成QNResponseInfo实例
@interface QNUploadInfoCollector : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
 *   注册上传统计实例
 *
 *   @param identifier  此次上传的唯一标识
 *   @param token       上传token
 *
 */
- (void)registerWithIdentifier:(NSString *)identifier token:(NSString *)token;

/**
*   更新QNCollectKey对应的上传信息
*
*   @param key              需要更新的QNCollectKey
*   @param identifier       此次上传的唯一标识
*
*/
- (void)update:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier;

/**
*   拼接QNCollectKey对应的上传信息   一般用于拼接数字类型常量
*
*   @param key              需要拼接的QNCollectKey
*   @param identifier       此次上传的唯一标识
*
*/
- (void)append:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier;

/**
*   记录此次上传中单次http请求结果
*
*   @param upType                 请求类型
*   @param httpResponseInfo   请求返回信息
*   @param fileOffset              data偏移量（非分片上传请求时该值为0）
*   @param targetRegionId       目标区域id
*   @param currentRegionId     当前区域id
*   @param identifier              此次上传的唯一标识
*
*/
- (void)addRequestWithType:(QNRequestType)upType httpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(int64_t)fileOffset targetRegionId:(NSString *)targetRegionId currentRegionId:(NSString *)currentRegionId identifier:(NSString *)identifier;

/**
*   根据http请求结果返回QNResponseInfo
*
*   @param lastHttpResponseInfo    最后一个请求的返回信息
*   @param identifier                    此次上传的唯一标识
*
*   @return QNResponseInfo          返回信息
*/
- (QNResponseInfo *)completeWithHttpResponseInfo:(QNHttpResponseInfo *)lastHttpResponseInfo identifier:(NSString *)identifier;

/**
*   参数问题导致上传结束并返回QNResponseInfo
*
*   @param text                     描述
*   @param identifier               此次上传的唯一标识
*
*   @return QNResponseInfo     返回信息
*/
- (QNResponseInfo *)completeWithInvalidArgument:(NSString *)text identifier:(NSString *)identifier;

/**
*   token无效导致上传结束并返回QNResponseInfo
*
*   @param text                     描述
*   @param identifier               此次上传的唯一标识
*
*   @return QNResponseInfo     返回信息
*/
- (QNResponseInfo *)completeWithInvalidToken:(NSString *)text identifier:(NSString *)identifier;

/**
*   文件内容出错导致上传结束并返回QNResponseInfo
*
*   @param error                    报错信息
*   @param identifier               此次上传的唯一标识
*
*   @return QNResponseInfo     返回信息
*/
- (QNResponseInfo *)completeWithFileError:(NSError *)error identifier:(NSString *)identifier;

/**
*   本地 I/O 出错导致上传结束并返回QNResponseInfo
*
*   @param error                    报错信息
*   @param identifier               此次上传的唯一标识
*
*   @return QNResponseInfo     返回信息
*/
- (QNResponseInfo *)completeWithLocalIOError:(NSError *)error identifier:(NSString *)identifier;

/**
*   zero data问题导致上传结束并返回QNResponseInfo
*
*   @param path                     文件路径
*   @param identifier               此次上传的唯一标识
*
*   @return QNResponseInfo     返回信息
*/
- (QNResponseInfo *)completeWithZeroData:(NSString *)path identifier:(NSString *)identifier;

/**
*   用户取消导致上传结束并返回QNResponseInfo
*
*   @param identifier               此次上传的唯一标识
*
*   @return QNResponseInfo     返回信息
*/
- (QNResponseInfo *)userCancel:(NSString *)identifier;

@end
