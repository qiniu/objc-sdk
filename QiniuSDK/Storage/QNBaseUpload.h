//
//  QNBaseUpload.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNConfiguration.h"
#import "QNCrc32.h"
#import "QNRecorderDelegate.h"
#import "QNSessionManager.h"
#import "QNUpToken.h"
#import "QNUrlSafeBase64.h"
#import "QNAsyncRun.h"
#import "QNUploadManager.h"
#import "QNUploadOption.h"


#import "QNZone.h"
#import "QNFileDelegate.h"
#import "QNUploadRequestMetrics.h"

typedef void (^QNUpTaskCompletionHandler)(QNResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp);

@interface QNBaseUpload : NSObject

@property (nonatomic,   copy, readonly) NSString *key;
@property (nonatomic,   copy, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, strong, readonly) id <QNFileDelegate> file;
@property (nonatomic, strong, readonly) QNUpToken *token;
@property (nonatomic, strong, readonly) QNUploadOption *option;
@property (nonatomic, strong, readonly) QNConfiguration *config;
@property (nonatomic, strong, readonly) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy, readonly) NSString *recorderKey;
@property (nonatomic, strong, readonly) QNUpTaskCompletionHandler completionHandler;

@property (nonatomic, strong, readonly) QNUploadRegionRequestMetrics *currentRegionRequestMetrics;
@property (nonatomic, strong, readonly) QNUploadTaskMetrics *metrics;


//MARK:-- 构造函数

/// file构造函数
/// @param file file信息
/// @param key 上传key
/// @param token 上传token
/// @param option 上传option
/// @param config 上传config
/// @param recorder 断点续传记录信息
/// @param recorderKey 断电上传信息保存的key值，需确保唯一性
/// @param completionHandler 上传完成回调
- (instancetype)initWithFile:(id<QNFileDelegate>)file
                         key:(NSString *)key
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
                    recorder:(id<QNRecorderDelegate>)recorder
                 recorderKey:(NSString *)recorderKey
           completionHandler:(QNUpTaskCompletionHandler)completionHandler;

/// data 构造函数
/// @param data 上传data流
/// @param key 上传key
/// @param fileName 上传fileName
/// @param token 上传token
/// @param option 上传option
/// @param config 上传config
/// @param completionHandler 上传完成回调
- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
           completionHandler:(QNUpTaskCompletionHandler)completionHandler;

/// 初始化数据
- (void)initData;

//MARK:-- 上传

/// 开始上传流程
- (void)run;

/// 准备上传
- (int)prepareToUpload;

/// 开始上传
- (void)startToUpload;

/// 切换区域
- (BOOL)switchRegionAndUpload;

/// 上传结束调用回调方法，在上传结束时调用，该方法内部会调用回调，已通知上层上传结束
/// @param info 上传返回信息
/// @param response 上传字典信息
- (void)complete:(QNResponseInfo *)info
        response:(NSDictionary *)response;

//MARK: -- 机房管理

/// 在区域列表头部插入一个区域
/// @param zoneInfo zone信息
- (void)insertRegionAtFirstByZoneInfo:(QNZoneInfo *)zoneInfo;
/// 切换区域
- (BOOL)switchRegion;
/// 获取目标区域
- (id <QNUploadRegion>)getTargetRegion;
/// 获取当前区域
- (id <QNUploadRegion>)getCurrentRegion;

//MARK: -- upLog

// 一个上传流程可能会发起多个上传操作（如：上传多个分片），每个上传操作均是以一个Region的host做重试操作
- (void)addRegionRequestMetricsOfOneFlow:(QNUploadRegionRequestMetrics *)metrics;

@end
