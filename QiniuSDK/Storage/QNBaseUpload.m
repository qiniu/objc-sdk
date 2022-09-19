//
//  QNBaseUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZoneInfo.h"
#import "QNResponseInfo.h"
#import "QNDefine.h"
#import "QNBaseUpload.h"
#import "QNUploadDomainRegion.h"

NSString *const QNUploadUpTypeForm = @"form";
NSString *const QNUploadUpTypeResumableV1 = @"resumable_v1";
NSString *const QNUploadUpTypeResumableV2 = @"resumable_v2";

@interface QNBaseUpload ()

@property (nonatomic, strong) QNBaseUpload *strongSelf;

@property (nonatomic,   copy) NSString *key;
@property (nonatomic,   copy) NSString *fileName;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) id <QNUploadSource> uploadSource;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic,   copy) NSString *identifier;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy) NSString *recorderKey;
@property (nonatomic, strong) QNUpTaskCompletionHandler completionHandler;

@property (nonatomic, assign)NSInteger currentRegionIndex;
@property (nonatomic, strong)NSMutableArray <id <QNUploadRegion> > *regions;

@property (nonatomic, strong)QNUploadRegionRequestMetrics *currentRegionRequestMetrics;
@property (nonatomic, strong) QNUploadTaskMetrics *metrics;

@end

@implementation QNBaseUpload

- (instancetype)initWithSource:(id<QNUploadSource>)uploadSource
                           key:(NSString *)key
                         token:(QNUpToken *)token
                        option:(QNUploadOption *)option
                 configuration:(QNConfiguration *)config
                      recorder:(id<QNRecorderDelegate>)recorder
                   recorderKey:(NSString *)recorderKey
             completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    return [self initWithSource:uploadSource data:nil fileName:[uploadSource getFileName] key:key token:token option:option configuration:config recorder:recorder recorderKey:recorderKey completionHandler:completionHandler];
}

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
           completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    return [self initWithSource:nil data:data fileName:fileName key:key token:token option:option configuration:config recorder:nil recorderKey:nil completionHandler:completionHandler];
}

- (instancetype)initWithSource:(id<QNUploadSource>)uploadSource
                          data:(NSData *)data
                      fileName:(NSString *)fileName
                           key:(NSString *)key
                         token:(QNUpToken *)token
                        option:(QNUploadOption *)option
                 configuration:(QNConfiguration *)config
                      recorder:(id<QNRecorderDelegate>)recorder
                   recorderKey:(NSString *)recorderKey
             completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    if (self = [super init]) {
        _uploadSource = uploadSource;
        _data = data;
        _fileName = fileName ?: @"?";
        _key = key;
        _token = token;
        _config = config;
        _option = option ?: [QNUploadOption defaultOptions];
        _recorder = recorder;
        _recorderKey = recorderKey;
        _completionHandler = completionHandler;
        [self initData];
    }
    return self;
}

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _strongSelf = self;
    _currentRegionIndex = 0;
}

- (void)run {
    [self.metrics start];
    
    kQNWeakSelf;
    [_config.zone preQuery:self.token on:^(int code, QNResponseInfo *responseInfo, QNUploadRegionRequestMetrics *metrics) {
        kQNStrongSelf;
        self.metrics.ucQueryMetrics = metrics;
        
        if (code == 0) {
            int prepareCode = [self prepareToUpload];
            if (prepareCode == 0) {
                [self startToUpload];
            } else {
                QNResponseInfo *responseInfoP = [QNResponseInfo errorResponseInfo:prepareCode errorDesc:nil];
                [self complete:responseInfoP response:responseInfoP.responseDictionary];
            }
        } else {
            [self complete:responseInfo response:responseInfo.responseDictionary];
        }
    }];
}

- (int)prepareToUpload{
    int ret = 0;
    if (![self setupRegions]) {
        ret = -1;
    }
    return ret;
}

- (void)startToUpload{
    self.currentRegionRequestMetrics = [[QNUploadRegionRequestMetrics alloc] initWithRegion:[self getCurrentRegion]];
    [self.currentRegionRequestMetrics start];
}

// 内部不再调用
- (BOOL)switchRegionAndUpload{
    if (self.currentRegionRequestMetrics) {
        [self.currentRegionRequestMetrics end];
        [self.metrics addMetrics:self.currentRegionRequestMetrics];
        self.currentRegionRequestMetrics = nil;
    }
    
    BOOL isSwitched = [self switchRegion];
    if (isSwitched) {
        [self startToUpload];
    }
    return isSwitched;
}

// 根据错误信息进行切换region并上传，return:是否切换region并上传
- (BOOL)switchRegionAndUploadIfNeededWithErrorResponse:(QNResponseInfo *)errorResponseInfo {
    if (!errorResponseInfo || errorResponseInfo.isOK || // 不存在 || 成功 不需要重试
        !errorResponseInfo.couldRetry || ![self.config allowBackupHost]) {  // 不能重试
        return NO;
    }
    
    if (self.currentRegionRequestMetrics) {
        [self.currentRegionRequestMetrics end];
        [self.metrics addMetrics:self.currentRegionRequestMetrics];
        self.currentRegionRequestMetrics = nil;
    }
    
    // 切换区域，当为 context 过期错误不需要切换区域
    if (!errorResponseInfo.isCtxExpiedError && ![self switchRegion]) {
        // 非 context 过期错误，但是切换 region 失败
        return false;
    }
    
    [self startToUpload];
    
    return true;
}

- (void)complete:(QNResponseInfo *)info
        response:(NSDictionary *)response{
    
    [self.metrics end];
    [self.currentRegionRequestMetrics end];
    
    if (self.currentRegionRequestMetrics) {
        [self.metrics addMetrics:self.currentRegionRequestMetrics];
    }
    if (self.completionHandler) {
        self.completionHandler(info, _key, _metrics, response);
    }
    self.strongSelf = nil;
}

//MARK:-- region
- (BOOL)setupRegions{
    NSMutableArray *defaultRegions = [NSMutableArray array];
    NSArray *zoneInfos = [self.config.zone getZonesInfoWithToken:self.token].zonesInfo;
    for (QNZoneInfo *zoneInfo in zoneInfos) {
        QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
        [region setupRegionData:zoneInfo];
        if (region.isValid) {
            [defaultRegions addObject:region];
        }
    }
    self.regions = defaultRegions;
    self.metrics.regions = defaultRegions;
    return defaultRegions.count > 0;
}

- (void)insertRegionAtFirst:(id <QNUploadRegion>)region{
    BOOL hasRegion = NO;
    for (id <QNUploadRegion> regionP in self.regions) {
        if ([regionP.zoneInfo.regionId isEqualToString:region.zoneInfo.regionId]) {
            hasRegion = YES;
            break;
        }
    }
    if (!hasRegion) {
        [self.regions insertObject:region atIndex:0];
    }
}

- (BOOL)switchRegion{
    BOOL ret = NO;
    @synchronized (self) {
        NSInteger regionIndex = _currentRegionIndex + 1;
        if (regionIndex < self.regions.count) {
            _currentRegionIndex = regionIndex;
            ret = YES;
        }
    }
    return ret;
}

- (id <QNUploadRegion>)getTargetRegion{
    return self.regions.firstObject;
}

- (id <QNUploadRegion>)getCurrentRegion{
    id <QNUploadRegion> region = nil;
    @synchronized (self) {
        if (self.currentRegionIndex < self.regions.count) {
            region = self.regions[self.currentRegionIndex];
        }
    }
    return region;
}

- (void)addRegionRequestMetricsOfOneFlow:(QNUploadRegionRequestMetrics *)metrics{
    if (metrics == nil) {
        return;
    }
    
    @synchronized (self) {
        if (self.currentRegionRequestMetrics == nil) {
            self.currentRegionRequestMetrics = metrics;
            return;
        }
    }
    
    [self.currentRegionRequestMetrics addMetrics:metrics];
}

- (QNUploadTaskMetrics *)metrics {
    if (_metrics == nil) {
        _metrics = [QNUploadTaskMetrics taskMetrics:self.upType];
    }
    return _metrics;
}
@end
