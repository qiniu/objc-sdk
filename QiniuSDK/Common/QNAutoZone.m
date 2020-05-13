//
//  QNAutoZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNAutoZone.h"
#import "QNRequestTranscation.h"
#import "QNZoneInfo.h"
#import "QNUpToken.h"
#import "QNResponseInfo.h"

@interface QNAutoZoneCache : NSObject
@property(nonatomic, strong)NSMutableDictionary *cache;
@end
@implementation QNAutoZoneCache

+ (instancetype)share{
    static QNAutoZoneCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[QNAutoZoneCache alloc] init];
        [cache setupData];
    });
    return cache;
}

- (void)setupData{
    self.cache = [NSMutableDictionary dictionary];
}

- (void)cache:(NSDictionary *)zonesInfo
     forToken:(QNUpToken *)token{
    
    NSString *cacheKey = token.index;
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return;
    }
    
    @synchronized (self) {
        if (zonesInfo) {
            self.cache[cacheKey] = zonesInfo;
        } else {
            [self.cache removeObjectForKey:cacheKey];
        }
    }
}

- (QNZonesInfo *)zonesInfoForToken:(QNUpToken *)token{
    
    NSString *cacheKey = token.index;
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }
    
    NSDictionary *zonesInfoDic = nil;
    @synchronized (self) {
        zonesInfoDic = self.cache[cacheKey];
    }
    
    if (zonesInfoDic == nil) {
        return nil;
    }
    
    QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:zonesInfoDic];
    NSMutableArray *zonesInfoArray = [NSMutableArray array];
    for (QNZoneInfo *zoneInfo in zonesInfo.zonesInfo) {
        if ([zoneInfo isValid]) {
            [zonesInfoArray addObject:zoneInfo];
        }
    }
    zonesInfo.zonesInfo = [zonesInfoArray copy];
    return zonesInfo;
}

@end

@interface QNAutoZone()

@property(nonatomic,  copy)NSString *server;
@property(nonatomic, strong)NSMutableDictionary *cache;
@property(nonatomic, strong)NSLock *lock;
@property(nonatomic, strong)NSMutableArray <QNRequestTranscation *> *transcations;

@end
@implementation QNAutoZone

- (instancetype)init{
    if (self = [super init]) {
        _server = @"https://uc.qbox.me";
        _cache = [NSMutableDictionary new];
        _lock = [NSLock new];
        _transcations = [NSMutableArray array];
    }
    return self;
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    if (token == nil) return nil;
    [_lock lock];
    QNZonesInfo *zonesInfo = [_cache objectForKey:[token index]];
    [_lock unlock];
    return zonesInfo;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    
    if (token == nil) {
        ret(-1, nil);
        return;
    }
    
    [_lock lock];
    QNZonesInfo *zonesInfo = [_cache objectForKey:[token index]];
    [_lock unlock];
    
    if (zonesInfo == nil) {
        zonesInfo = [[QNAutoZoneCache share] zonesInfoForToken:token];
        [self.lock lock];
        [self.cache setValue:zonesInfo forKey:[token index]];
        [self.lock unlock];
    }
    
    if (zonesInfo != nil) {
        ret(0, nil);
        return;
    }

    QNRequestTranscation *transcation = [self createUploadRequestTranscation:token];
    [transcation quertUploadHosts:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {

        if (!responseInfo.error) {
        
            QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:response];
            if (responseInfo == nil) {
                ret(kQNInvalidToken, responseInfo);
            } else {
                [self.lock lock];
                [self.cache setValue:zonesInfo forKey:[token index]];
                [self.lock unlock];
                [[QNAutoZoneCache share] cache:response forToken:token];
                ret(0, responseInfo);
            }
        } else {
            ret(kQNNetworkError, responseInfo);
        }
    }];
}

- (QNRequestTranscation *)createUploadRequestTranscation:(QNUpToken *)token{
    QNRequestTranscation *transcation = [[QNRequestTranscation alloc] initWithHosts:@[@"uc.qbox.me"] token:token];
    [self.transcations addObject:transcation];
    return transcation;
}

- (void)destoryUploadRequestTranscation:(QNRequestTranscation *)transcation{
    if (transcation) {
        [self.transcations removeObject:transcation];
    }
}

@end
