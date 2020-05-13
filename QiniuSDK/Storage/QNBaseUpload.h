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
#import "QNHttpResponseInfo.h"
#import "QNSessionManager.h"
#import "QNUpToken.h"
#import "QNUrlSafeBase64.h"
#import "QNAsyncRun.h"
#import "QNUploadInfoCollector.h"
#import "QNUploadManager.h"
#import "QNUploadOption.h"


#import "QNZone.h"
#import "QNFileDelegate.h"
#import "QNUploadFixedHostRegion.h"
#import "QNUploadRequestMetrics.h"

typedef void (^QNUpTaskCompletionHandler)(QNResponseInfo *info, NSString *key, QNUploadTaskMetrics *metrics, NSDictionary *resp);;
@interface QNBaseUpload : NSObject

@property (nonatomic,   copy, readonly) NSString *key;
@property (nonatomic,   copy, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, strong, readonly) QNUploadTaskMetrics *metrics;
@property (nonatomic, strong, readonly) id <QNFileDelegate> file;
@property (nonatomic, strong, readonly) QNUpToken *token;
@property (nonatomic,   copy, readonly) NSString *identifier;
@property (nonatomic, strong, readonly) QNUploadOption *option;
@property (nonatomic, strong, readonly) QNConfiguration *config;
@property (nonatomic, strong, readonly) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy, readonly) NSString *recorderKey;
@property (nonatomic, strong, readonly) QNUpTaskCompletionHandler completionHandler;

//MARK:-- 构造函数
- (instancetype)initWithFile:(id<QNFileDelegate>)file
                         key:(NSString *)key
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
                    recorder:(id<QNRecorderDelegate>)recorder
                 recorderKey:(NSString *)recorderKey
           completionHandler:(QNUpTaskCompletionHandler)completionHandler;

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
           completionHandler:(QNUpTaskCompletionHandler)completionHandler;

- (void)initData;

//MARK:-- 上传
- (void)run;

- (void)prepareToUpload;

- (void)startToUpload;

- (void)switchRegionAndUpload;

- (void)complete:(QNResponseInfo *)info
            resp:(NSDictionary *)resp;

//MARK:-- 上传质量统计
- (void)collectHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(uint64_t)fileOffset;

- (void)collectUploadQualityInfo;



//MARK: -- 机房管理
/// 在区域列表头部插入一个区域
- (void)insertRegionAtFirstByZoneInfo:(QNZoneInfo *)zoneInfo;
/// 切换区域
- (BOOL)switchRegion;
/// 获取当前区域
- (id <QNUploadRegion>)getCurrentRegion;

@end
