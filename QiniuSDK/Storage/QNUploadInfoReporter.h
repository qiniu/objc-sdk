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

// base item
@interface QNReportBaseItem : NSObject
- (NSString *)toJson; // get json with report item
@end

// request type item - 用于统计单个请求的打点信息
@interface QNReportRequestItem : QNReportBaseItem
+ (instancetype)buildWithUpType:(NSString *)up_type
                   TargetBucket:(NSString *)target_bucket
                      targetKey:(NSString *)target_key
                     fileOffset:(int64_t)file_offset
                 targetRegionId:(NSString *)target_region_id
                currentRegionId:(NSString *)current_region_id
              prefetchedIpCount:(int64_t)prefetched_ip_count
                            pid:(int64_t)pid
                            tid:(int64_t)tid
                     statusCode:(int64_t)status_code
                          reqId:(NSString *)req_id
                           host:(NSString *)host
                       remoteIp:(NSString *)remote_ip
                           port:(int64_t)port
               totalElapsedTime:(int64_t)total_elapsed_time
                 dnsElapsedTime:(int64_t)dns_elapsed_time
             connectElapsedTime:(int64_t)connect_elapsed_time
          tlsConnectElapsedTime:(int64_t)tls_connect_elapsed_time
             requestElapsedTime:(int64_t)request_elapsed_time
                waitElapsedTime:(int64_t)wait_elapsed_time
            responseElapsedTime:(int64_t)response_elapsed_time
                      bytesSent:(int64_t)bytes_sent
                     bytesTotal:(int64_t)bytes_total
                      errorType:(NSString *)error_type
               errorDescription:(NSString *)error_description
                    networkType:(NSString *)network_type
                 signalStrength:(int64_t)signal_strength;

@end

// block type item - 用于统计分片上传整体质量信息
@interface QNReportBlockItem : QNReportBaseItem
+ (instancetype)buildWithTargetRegionId:(NSString *)target_region_id
                        currentRegionId:(NSString *)current_region_id
                       totalElapsedTime:(int64_t)total_elapsed_time
                              bytesSent:(int64_t)bytes_sent
                          recoveredFrom:(int64_t)recovered_from
                               fileSize:(int64_t)file_size
                                    pid:(int64_t)pid
                                    tid:(int64_t)tid
                           upApiVersion:(int64_t)up_api_version;

@end

// quality type item - 用于统计上传结果
@interface QNReportQualityItem : QNReportBaseItem
+ (instancetype)buildWithResult:(NSString *)result
               totalElapsedTime:(int64_t)total_elapsed_time
                  requestsCount:(int64_t)requests_count
                   regionsCount:(int64_t)regions_count
                      bytesSent:(int64_t)bytes_sent;
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

@property (nonatomic, copy, readonly) NSString *X_Log_Client_Id;

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
