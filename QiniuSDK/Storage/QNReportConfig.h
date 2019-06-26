//
//  QNReportConfig.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNReportConfig : NSObject

+ (instancetype)sharedInstance;

/**
 *  是否开启sdk上传信息搜集  默认为YES
 */
@property (nonatomic, assign, getter=isRecordEnable) BOOL recordEnable;

/**
 *  每次上传最小时间间隔  单位：分钟
 */
@property (nonatomic, assign) int interval;

/**
 *  信息上报服务器地址
 */
@property (nonatomic, copy, readonly) NSString *serverURL;

/**
 *  记录文件所在文件夹目录  默认为：.../沙盒/Library/Caches/com.qiniu.report
 */
@property (nonatomic, copy, readonly) NSString *recordDirectory;

/**
 *  记录文件最大值  单位：字节
 */
@property (nonatomic, assign, readonly) int64_t maxRecordFileSize;

/**
 *  记录文件大于 uploadThreshold 后才可能触发上传，单位：字节。
 */
@property (nonatomic, assign, readonly) int64_t uploadThreshold;

/**
 *  信息上报请求超时时间  单位：秒
 */
@property (nonatomic, assign, readonly) NSTimeInterval timeoutInterval;

@end
