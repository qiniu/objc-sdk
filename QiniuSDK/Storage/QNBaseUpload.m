//
//  QNBaseUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/19.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNBaseUpload.h"
#import "QNUploadDomainRegion.h"

@interface QNBaseUpload ()

@property (nonatomic,   copy) NSString *key;
@property (nonatomic,   copy) NSString *fileName;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) id <QNFileDelegate> file;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic,   copy) NSString *identifier;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id <QNRecorderDelegate> recorder;
@property (nonatomic,   copy) NSString *recorderKey;
@property (nonatomic, strong) QNUpTaskCompletionHandler completionHandler;

@property (nonatomic, assign) QNRequestType requestType;
@property (nonatomic, assign)NSInteger currentRegionIndex;
@property (nonatomic, strong)NSArray <id <QNUploadRegion> > *regions;

@end

@implementation QNBaseUpload
- (instancetype)initWithFile:(id<QNFileDelegate>)file
                         key:(NSString *)key
                       token:(QNUpToken *)token
                  identifier:(NSString *)identifier
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
                    recorder:(id<QNRecorderDelegate>)recorder
                 recorderKey:(NSString *)recorderKey
           completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    return [self initWithFile:file data:nil fileName:[[file path] lastPathComponent] key:key token:token option:option configuration:config recorder:recorder recorderKey:recorderKey completionHandler:completionHandler];
}

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(QNUpToken *)token
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
           completionHandler:(QNUpTaskCompletionHandler)completionHandler{
    return [self initWithFile:nil data:data fileName:fileName key:key token:token option:option configuration:config recorder:nil recorderKey:nil completionHandler:completionHandler];
}

- (instancetype)initWithFile:(id<QNFileDelegate>)file
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
        _file = file;
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
    _currentRegionIndex = 0;
    _metrics = [[QNUploadTaskMetrics alloc] init];
}

- (void)run {
    [self prepareToUpload];
    [self startToUpload];
}

- (void)prepareToUpload{
    [self setupRegions];
}

- (void)startToUpload{
}

- (void)switchRegionAndUpload{
    QNAsyncRun(^{
        [self switchRegion];
        [self startToUpload];
    });
}

- (void)complete:(QNResponseInfo *)info
            resp:(NSDictionary *)resp{
    if (self.completionHandler) {
        self.completionHandler(info, _key, _metrics, resp);
    }
}

//MARK:-- qulite collect
- (void)collectHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(uint64_t)fileOffset {
    
}

- (void)collectUploadQualityInfo {
    
}

//MARK:-- region
- (void)setupRegions{
    NSMutableArray *defaultRegions = [NSMutableArray array];
    NSArray *zoneInfos = [self.config.zone getZonesInfoWithToken:self.token].zonesInfo;
    for (QNZoneInfo *zoneInfo in zoneInfos) {
        QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
        [region setupRegionData:zoneInfo];
        [defaultRegions addObject:region];
    }
    self.regions = [defaultRegions copy];
}

- (void)insertRegionAtFirstByZoneInfo:(QNZoneInfo *)zoneInfo{
    QNUploadDomainRegion *region = [[QNUploadDomainRegion alloc] init];
    [region setupRegionData:zoneInfo];
    [self insertRegionAtFirst:region];
}

- (void)insertRegionAtFirst:(id <QNUploadRegion>)region{
    
}

- (BOOL)switchRegion{
    BOOL ret = NO;
    @synchronized (self) {
        _currentRegionIndex += 1;
        if (_currentRegionIndex < self.regions.count) {
            ret = YES;
        }
    }
    return ret;
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
@end
