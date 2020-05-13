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
#define kQNReporter [QNUploadInfoReporter sharedInstance]
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

