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
@property (nonatomic, strong) QNUpCompletionHandler completionHandler;

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
           completionHandler:(QNUpCompletionHandler)completionHandler{
    return [self initWithFile:file data:nil fileName:[[file path] lastPathComponent] key:key token:token identifier:identifier option:option configuration:config recorder:recorder recorderKey:recorderKey completionHandler:completionHandler];
}

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    fileName:(NSString *)fileName
                       token:(QNUpToken *)token
                  identifier:(NSString *)identifier
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
           completionHandler:(QNUpCompletionHandler)completionHandler{
    return [self initWithFile:nil data:data fileName:fileName key:key token:token identifier:identifier option:option configuration:config recorder:nil recorderKey:nil completionHandler:completionHandler];
}

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                        data:(NSData *)data
                    fileName:(NSString *)fileName
                         key:(NSString *)key
                       token:(QNUpToken *)token
                  identifier:(NSString *)identifier
                      option:(QNUploadOption *)option
               configuration:(QNConfiguration *)config
                    recorder:(id<QNRecorderDelegate>)recorder
                 recorderKey:(NSString *)recorderKey
           completionHandler:(QNUpCompletionHandler)completionHandler{
    if (self = [super init]) {
        _file = file;
        _data = data;
        _fileName = fileName ?: @"?";
        _key = key;
        _token = token;
        _identifier = identifier;
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
    [self switchRegion];
    [self startToUpload];
}

//MARK:-- qulite collect
- (void)collectHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(uint64_t)fileOffset {
    
    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
    NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
    NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
    
    [Collector addRequestWithType:self.requestType httpResponseInfo:httpResponseInfo fileOffset:fileOffset targetRegionId:targetRegionId currentRegionId:currentRegionId identifier:self.identifier];
    
    uint64_t bytesSent;
    if (self.requestType == QNRequestType_mkblk || self.requestType == QNRequestType_bput) {
        if (httpResponseInfo.hasHttpResponse) {
            bytesSent = httpResponseInfo.bytesTotal;
        } else {
            bytesSent = 0;
        }
        [Collector append:CK_blockBytesSent value:@(bytesSent) identifier:self.identifier];
    } else {
        bytesSent = httpResponseInfo.bytesSent;
    }
    
    [Collector append:CK_totalBytesSent value:@(bytesSent) identifier:self.identifier];
}

- (void)collectUploadQualityInfo {
    
    QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
    NSString *targetRegionId = [zonesInfo getZoneInfoRegionNameWithType:QNZoneInfoTypeMain];
    NSString *currentRegionId = [zonesInfo getZoneInfoRegionNameWithType:self.currentZoneType];
    [Collector update:CK_targetRegionId value:targetRegionId identifier:self.identifier];
    [Collector update:CK_currentRegionId value:currentRegionId identifier:self.identifier];
    [Collector update:CK_fileSize value:@(self.size) identifier:self.identifier];
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
