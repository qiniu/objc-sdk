//
//  QNUploadInfoReporter.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNHttpDelegate.h"

typedef NS_ENUM(NSUInteger, QNReportType) {
    ReportType_form,
    ReportType_mkblk,
    ReportType_bput,
    ReportType_mkfile,
    ReportType_block
};

@interface QNReportConfig : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
 *  是否开启sdk上传信息搜集  默认为YES
 */
@property (nonatomic, assign, getter=isRecordEnable) BOOL recordEnable;

/**
 *  每次上传最小时间间隔  单位：分钟
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



#define UploadInfoReporter [QNUploadInfoReporter sharedInstance]

@interface QNUploadInfoReporter : NSObject

@property (nonatomic, assign, readonly) NSTimeInterval lastReportTime;

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
*    上报统计信息
*
*    @param requestType 请求类型
*    @param responseInfo 返回信息
*    @param bytesSent  已发送的字节数
*    @param fileSize   总字节数
*    @param token   上传凭证
*
*/
- (void)recordWithRequestType:(QNReportType)requestType
                 responseInfo:(QNResponseInfo *)responseInfo
                    bytesSent:(UInt32)bytesSent
                     fileSize:(UInt32)fileSize
                        token:(NSString *)token;

/**
 *    清空统计信息
 */
- (void)clean;

@end
