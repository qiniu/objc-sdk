//
//  QNPartsUploadPerformer.h
//  QiniuSDK
//
//  Created by yangsen on 2020/12/1.
//  Copyright © 2020 Qiniu. All rights reserved.
//
/// 抽象类，不可以直接使用，需要使用子类

#import "QNFileDelegate.h"
#import "QNUploadSource.h"
#import "QNResponseInfo.h"
#import "QNUploadOption.h"
#import "QNConfiguration.h"
#import "QNUpToken.h"

NS_ASSUME_NONNULL_BEGIN

@protocol QNUploadRegion;
@class QNUploadInfo, QNRequestTransaction, QNUploadRegionRequestMetrics;

@interface QNPartsUploadPerformer : NSObject

@property (nonatomic,   copy, readonly) NSString *key;
@property (nonatomic,   copy, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) id <QNUploadSource> uploadSource;
@property (nonatomic, strong, readonly) QNUpToken *token;

@property (nonatomic, strong, readonly) QNUploadOption *option;
@property (nonatomic, strong, readonly) QNConfiguration *config;
@property (nonatomic, strong, readonly) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy, readonly) NSString *recorderKey;

/// 断点续传时，起始上传偏移
@property(nonatomic, strong, readonly)NSNumber *recoveredFrom;
@property(nonatomic, strong, readonly)id <QNUploadRegion> currentRegion;
@property(nonatomic, strong, readonly)QNUploadInfo *uploadInfo;

- (instancetype)initWithSource:(id<QNUploadSource>)uploadSource
                      fileName:(NSString *)fileName
                           key:(NSString *)key
                         token:(QNUpToken *)token
                        option:(QNUploadOption *)option
                 configuration:(QNConfiguration *)config
                   recorderKey:(NSString *)recorderKey;

- (void)switchRegion:(id <QNUploadRegion>)region;

/// 通知回调当前进度
- (void)notifyProgress;

/// 分片信息保存本地
- (void)recordUploadInfo;
/// 分片信息从本地移除
- (void)removeUploadInfoRecord;

/// 根据字典构造分片信息 【子类实现】
- (QNUploadInfo *)getFileInfoWithDictionary:(NSDictionary * _Nonnull)fileInfoDictionary;
/// 根据配置构造分片信息 【子类实现】
- (QNUploadInfo *)getDefaultUploadInfo;

- (QNRequestTransaction *)createUploadRequestTransaction;
- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction;

/// 上传前，服务端配置工作 【子类实现】
- (void)serverInit:(void(^)(QNResponseInfo * _Nullable responseInfo,
                            QNUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler;
/// 上传文件分片 【子类实现】
- (void)uploadNextData:(void(^)(BOOL stop,
                                QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler;
/// 完成上传，服务端组织文件信息 【子类实现】
- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler;

@end

NS_ASSUME_NONNULL_END
