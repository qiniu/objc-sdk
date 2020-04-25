//
//  QNUploadInfoReporter.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@class QNResponseInfo;

// Upload Result Type
extern NSString *const upload_ok;   // 上传成功
extern NSString *const zero_size_file;  // ⽂件⼤小错误
extern NSString *const invalid_file;  // 文件内容错误
extern NSString *const invalid_args; // 调用参数出错

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

// base item
@interface QNReportBaseItem : NSObject
- (NSString *)toJson; // get json with report item
@end

// request type item - 用于统计单个请求的打点信息
@interface QNReportRequestItem : QNReportBaseItem
- (id)init __attribute__((unavailable("Use buildWith: instead.")));
+ (instancetype)buildWithUpType:(NSString *)up_type
                   TargetBucket:(NSString *)target_bucket
                      targetKey:(NSString *)target_key
                     fileOffset:(uint64_t)file_offset
                 targetRegionId:(NSString *)target_region_id
                currentRegionId:(NSString *)current_region_id
              prefetchedIpCount:(int64_t)prefetched_ip_count
                            pid:(int64_t)pid
                            tid:(int64_t)tid
                     statusCode:(int16_t)status_code
                          reqId:(NSString *)req_id
                           host:(NSString *)host
                       remoteIp:(NSString *)remote_ip
                           port:(uint16_t)port
               totalElapsedTime:(uint64_t)total_elapsed_time
                 dnsElapsedTime:(uint64_t)dns_elapsed_time
             connectElapsedTime:(uint64_t)connect_elapsed_time
          tlsConnectElapsedTime:(uint64_t)tls_connect_elapsed_time
             requestElapsedTime:(uint64_t)request_elapsed_time
                waitElapsedTime:(uint64_t)wait_elapsed_time
            responseElapsedTime:(uint64_t)response_elapsed_time
                      bytesSent:(uint64_t)bytes_sent
                     bytesTotal:(uint64_t)bytes_total
                      errorType:(NSString *)error_type
               errorDescription:(NSString *)error_description
                    networkType:(NSString *)network_type
                 signalStrength:(int64_t)signal_strength;

@end

// block type item - 用于统计分片上传整体质量信息
@interface QNReportBlockItem : QNReportBaseItem
- (id)init __attribute__((unavailable("Use buildWith: instead.")));
+ (instancetype)buildWithTargetRegionId:(NSString *)target_region_id
                        currentRegionId:(NSString *)current_region_id
                       totalElapsedTime:(uint64_t)total_elapsed_time
                              bytesSent:(uint64_t)bytes_sent
                          recoveredFrom:(uint64_t)recovered_from
                               fileSize:(uint64_t)file_size
                                    pid:(int64_t)pid
                                    tid:(int64_t)tid
                           upApiVersion:(uint8_t)up_api_version;

@end

// quality type item - 用于统计上传结果
@interface QNReportQualityItem : QNReportBaseItem
- (id)init __attribute__((unavailable("Use buildWith: instead.")));
+ (instancetype)buildWithResult:(NSString *)result
               totalElapsedTime:(uint64_t)total_elapsed_time
                  requestsCount:(uint64_t)requests_count
                   regionsCount:(uint64_t)regions_count
                      bytesSent:(uint64_t)bytes_sent;
@end

@interface QNReportConfig : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
 *  是否开启sdk上传信息搜集  默认为YES
 */
@property (nonatomic, assign, getter=isReportEnable) BOOL reportEnable;

/**
 *  每次上传最小时间间隔  单位：分钟  默认为10分钟
 */
@property (nonatomic, assign) uint32_t interval;

/**
 *  记录文件大于 uploadThreshold 后才可能触发上传，单位：字节  默认为4 * 1024
 */
@property (nonatomic, assign) uint64_t uploadThreshold;

/**
 *  记录文件最大值  要大于 uploadThreshold  单位：字节  默认为2 * 1024 * 1024
 */
@property (nonatomic, assign) uint64_t maxRecordFileSize;

/**
 *  记录文件所在文件夹目录  默认为：.../沙盒/Library/Caches/com.qiniu.report
 */
@property (nonatomic, copy) NSString *recordDirectory;

/**
 *  信息上报服务器地址
 */
@property (nonatomic, copy, readonly) NSString *serverURL;

/**
 *  信息上报请求超时时间  单位：秒  默认为10秒
 */
@property (nonatomic, assign, readonly) NSTimeInterval timeoutInterval;

@end



#define Reporter [QNUploadInfoReporter sharedInstance]

@interface QNUploadInfoReporter : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
*    上报统计信息
*
*    @param jsonString  需要记录的json字符串
*    @param token   上传凭证
*
*/
- (void)report:(NSString *)jsonString token:(NSString *)token;

/**
 *    清空统计信息
 */
- (void)clean;

@end
