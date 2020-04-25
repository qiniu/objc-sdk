//
//  QNHttpResponseInfo.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QNSessionStatistics;

@interface QNHttpResponseInfo : NSObject

/**
 *    状态码
 */
@property (nonatomic, assign, readonly) int statusCode;

/**
 *    服务器域名
 */
@property (nonatomic, copy, readonly) NSString *host;

/**
 *    错误信息
 */
@property (nonatomic, copy, readonly) NSError *error;

/**
 *    是否有httpResponse
 */
@property (nonatomic, assign, readonly) BOOL hasHttpResponse;

/**
 *    七牛服务器生成的请求ID
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
 *    成功的请求
 */
@property (nonatomic, assign, readonly, getter=isOK) BOOL ok;

/**
 *    是否需要重试
 */
@property (nonatomic, assign, readonly) BOOL couldRetry;

/**
*    服务端ip
*/
@property (nonatomic, copy, readonly) NSString *remoteIp;

/**
*    服务端端口号
*/
@property (nonatomic, assign, readonly) uint16_t port;

/**
 *   当前时间戳
 */
@property (nonatomic, assign, readonly) uint64_t timeStamp;

/**
*    从发送请求到收到响应之间的单调时间差，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t totalElapsedTime;

/**
*    一次请求中 DNS 查询的耗时，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t dnsElapsedTime;

/**
*    ⼀次请求中建立网络连接的耗时，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t connectElapsedTime;

/**
*    ⼀次请求中建立安全⽹络连接的耗时，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t tlsConnectElapsedTime;

/**
*    ⼀次请求中发送请求的耗时，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t requestElapsedTime;

/**
*   ⼀次请求中从发送请求完毕到收到响应前的耗时，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t waitElapsedTime;

/**
*    ⼀次请求中读取响应的耗时，单位为毫秒
*/
@property (nonatomic, assign, readonly) uint64_t responseElapsedTime;

/**
*    本次成功发送请求的请求体大⼩，单位为字节
*/
@property (nonatomic, assign, readonly) uint64_t bytesSent;

/**
*    预期发送请求的请求体大小，单位为字节
*/
@property (nonatomic, assign, readonly) uint64_t bytesTotal;

/**
*    错误类型 用于信息上报
*/
@property (nonatomic, copy, readonly) NSString *errorType;

/**
*    错误描述 用于信息上报
*/
@property (nonatomic, copy, readonly) NSString *errorDescription;

/**
*    请求是否经过代理服务器
*/
@property (nonatomic, assign, readonly, getter=isProxyConnection) BOOL proxyConnection;

/**
*    请求完成时回调的进程id
*/
@property (nonatomic, assign, readonly) int64_t pid;

/**
*    请求完成时回调的线程id
*/
@property (nonatomic, assign, readonly) int64_t tid;

/**
*    请求结束时的网络类型
*/
@property (nonatomic, copy, readonly) NSString *networkType;

/**
*    请求结束时的信号强度
*/
@property (nonatomic, assign, readonly) int64_t signalStrength;

/**
 *    构造函数
 *
 *    @param host  请求域名
 *    @param response  httpReponse
 *    @param body   httpBody
 *    @param error   错误信息
 *    @param sessionStatistics   上传统计数据
 *
 *    @return 实例
 */
+ (QNHttpResponseInfo *)buildResponseInfoHost:(NSString *)host
                                     response:(NSHTTPURLResponse *)response
                                         body:(NSData *)body
                                        error:(NSError *)error
                            sessionStatistics:(QNSessionStatistics *)sessionStatistics;

/**
*    status == 200 时获取解析后的response body
*/
- (NSDictionary *)getResponseBody;

@end
