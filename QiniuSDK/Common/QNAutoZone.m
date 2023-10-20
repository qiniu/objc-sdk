//
//  QNAutoZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNCache.h"
#import "QNUtils.h"
#import "QNAutoZone.h"
#import "QNConfig.h"
#import "QNRequestTransaction.h"
#import "QNZoneInfo.h"
#import "QNUpToken.h"
#import "QNResponseInfo.h"
#import "QNFixedZone.h"
#import "QNSingleFlight.h"
#import "QNFileRecorder.h"
#import "QNUrlSafeBase64.h"
#import "QNUploadRequestMetrics.h"

@interface QNUCQuerySingleFlightValue : NSObject

@property(nonatomic, strong) QNResponseInfo *responseInfo;
@property(nonatomic, strong) NSDictionary *response;
@property(nonatomic, strong) QNUploadRegionRequestMetrics *metrics;

@end

@implementation QNUCQuerySingleFlightValue
@end

@interface QNAutoZone ()

@property(nonatomic, strong) NSArray *ucHosts;
@property(nonatomic, strong) QNFixedZone *defaultZone;
// 已经查询到的区域信息
@property(nonatomic, strong) NSMutableDictionary <NSString *, QNZonesInfo *> *zonesDic;
@property(nonatomic, strong) NSMutableArray <QNRequestTransaction *> *transactions;

@end

@implementation QNAutoZone

+ (QNSingleFlight *)UCQuerySingleFlight {
    static QNSingleFlight *singleFlight = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleFlight = [[QNSingleFlight alloc] init];
    });
    return singleFlight;
}

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts {
    QNAutoZone *zone = [[self alloc] init];
    zone.ucHosts = [ucHosts copy];
    return zone;
}

+ (QNCache *)zoneShareCache {
    static QNCache *queryCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        QNCacheOption *option = [[QNCacheOption alloc] init];
        option.version = @"v1.0.0";
        queryCache = [QNCache cache:[QNZonesInfo class] option:option];
    });
    return queryCache;
}

+ (void)clearCache {
    [[QNAutoZone zoneShareCache] clearMemoryCache];
    [[QNAutoZone zoneShareCache] clearDiskCache];
}

- (instancetype)init {
    if (self = [super init]) {
        _zonesDic = [NSMutableDictionary dictionary];
        _transactions = [NSMutableArray array];
    }
    return self;
}

- (void)setDefaultZones:(NSArray <QNFixedZone *> *)zones {
    self.defaultZone = [QNFixedZone combineZones:zones];
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *_Nullable)token {

    if (token == nil) return nil;
    NSString *cacheKey = [self makeCacheKey:token.index];
    QNZonesInfo *zonesInfo = nil;
    @synchronized (self) {
        zonesInfo = self.zonesDic[cacheKey];
    }
    zonesInfo = [zonesInfo copy];
    return zonesInfo;
}

- (void)setZonesInfo:(QNZonesInfo *)info forKey:(NSString *)key {
    if (info == nil) {
        return;
    }
    
    @synchronized (self) {
        self.zonesDic[key] = info;
    }
}

- (void)preQuery:(QNUpToken *)token on:(QNPrequeryReturn)ret {

    if (token == nil || ![token isValid]) {
        ret(-1, [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"], nil);
        return;
    }

    QNUploadRegionRequestMetrics *cacheMetrics = [QNUploadRegionRequestMetrics emptyMetrics];
    [cacheMetrics start];

    NSString *cacheKey = [self makeCacheKey:token.index];
    QNZonesInfo *zonesInfo = [[QNAutoZone zoneShareCache] cacheForKey:cacheKey];

    // 临时的 zonesInfo 仅能使用一次
    if (zonesInfo != nil && zonesInfo.isValid && !zonesInfo.isTemporary) {
        [cacheMetrics end];
        [self setZonesInfo:zonesInfo forKey:cacheKey];
        ret(0, [QNResponseInfo successResponse], cacheMetrics);
        return;
    }

    __block int32_t saveTime = 0;
    kQNWeakSelf;
    QNSingleFlight *singleFlight = [QNAutoZone UCQuerySingleFlight];
    [singleFlight perform:token.index action:^(QNSingleFlightComplete _Nonnull complete) {
        kQNStrongSelf;
        QNRequestTransaction *transaction = [self createUploadRequestTransaction:token];

        kQNWeakSelf;
        kQNWeakObj(transaction);
        [transaction queryUploadHosts:^(QNResponseInfo *_Nullable responseInfo, QNUploadRegionRequestMetrics *_Nullable metrics, NSDictionary *_Nullable response) {
            kQNStrongSelf;
            kQNStrongObj(transaction);

            QNUCQuerySingleFlightValue *value = [[QNUCQuerySingleFlightValue alloc] init];
            value.responseInfo = responseInfo;
            value.response = response;
            value.metrics = metrics;
            complete(value, nil);

            [self destroyUploadRequestTransaction:transaction];
        }];

    }            complete:^(id _Nullable value, NSError *_Nullable error) {
        kQNStrongSelf;
        
        QNResponseInfo *responseInfo = [(QNUCQuerySingleFlightValue *) value responseInfo];
        NSDictionary *response = [(QNUCQuerySingleFlightValue *) value response];
        QNUploadRegionRequestMetrics *metrics = [(QNUCQuerySingleFlightValue *) value metrics];

        if (responseInfo && responseInfo.isOK) {
            QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:response];
            if ([zonesInfo isValid]) {
                @synchronized (cacheKey) {
                    if (saveTime == 0) {
                        saveTime++;
                        [self setZonesInfo:zonesInfo forKey:cacheKey];
                        [[QNAutoZone zoneShareCache] cache:zonesInfo forKey:cacheKey atomically:false];
                    }
                }
                ret(0, responseInfo, metrics);
            } else {
                ret(NSURLErrorCannotDecodeRawData, responseInfo, metrics);
            }
        } else {
            if (self.defaultZone != nil) {
                // 备用只能用一次
                QNZonesInfo *info = [self.defaultZone getZonesInfoWithToken:token];
                [self setZonesInfo:info forKey:cacheKey];
                ret(0, responseInfo, metrics);
            } else if (zonesInfo != nil) {
                // 缓存有，但是失效也可使用
                [self setZonesInfo:zonesInfo forKey:cacheKey];
                ret(0, responseInfo, metrics);
            } else {
                ret(kQNNetworkError, responseInfo, metrics);
            }
        }
    }];
}

- (QNRequestTransaction *)createUploadRequestTransaction:(QNUpToken *)token {
    NSArray *hosts = nil;
    if (self.ucHosts && self.ucHosts.count > 0) {
        hosts = [self.ucHosts copy];
    } else {
        hosts = kQNPreQueryHosts;
    }
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:hosts
                                                                           regionId:QNZoneInfoEmptyRegionId
                                                                              token:token];
    @synchronized (self) {
        [self.transactions addObject:transaction];
    }
    return transaction;
}

- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction {
    if (transaction) {
        @synchronized (self) {
            [self.transactions removeObject:transaction];
        }
    }
}

- (NSString *)makeCacheKey:(NSString *)akAndBucket {
    NSString *ucHost = self.ucHosts.firstObject;
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", ucHost, akAndBucket];
    return [QNUrlSafeBase64 encodeString:cacheKey];
}

@end
