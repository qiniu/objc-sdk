//
//  QNAutoZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
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

@interface QNAutoZoneDiskCache : NSObject

@property(nonatomic, strong) QNFileRecorder *recorder;

@end

@implementation QNAutoZoneDiskCache

+ (instancetype)share {
    static QNAutoZoneDiskCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[QNAutoZoneDiskCache alloc] init];
        [cache setupData];
    });
    return cache;
}

- (void)setupData {
    self.recorder = [QNFileRecorder fileRecorderWithFolder:[[QNUtils sdkCacheDirectory] stringByAppendingString:@"/query"] error:nil];
}

- (void)cache:(QNZonesInfo *)zonesInfo forKey:(NSString *)cacheKey {
    if (!cacheKey || [cacheKey isEqualToString:@""] || zonesInfo == nil || zonesInfo.detailInfo == nil || !zonesInfo.isValid) {
        return;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:zonesInfo.detailInfo options:NSJSONWritingPrettyPrinted error:nil];
    @synchronized (self) {
        if (data) {
            [self.recorder set:cacheKey data:data];
        }
    }
}

- (QNZonesInfo *)cacheForKey:(NSString *)cacheKey {
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }

    NSData *data = nil;
    @synchronized (self) {
        data = [self.recorder get:cacheKey];
    }
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil || ![info isKindOfClass:[NSDictionary class]]) {
        [self.recorder del:cacheKey];
        return nil;
    }

    QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:info];
    if (zonesInfo != nil && zonesInfo.zonesInfo != nil && zonesInfo.zonesInfo.count > 0) {
        return zonesInfo;
    }
    
    return nil;
}


- (void)clearCache {
    @synchronized (self) {
        [self.recorder delAll];
    }
}

@end


@interface QNAutoZoneCache : NSObject
@property(nonatomic, strong) NSMutableDictionary *cache;
@end

@implementation QNAutoZoneCache

+ (instancetype)share {
    static QNAutoZoneCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[QNAutoZoneCache alloc] init];
        [cache setupData];
    });
    return cache;
}

- (void)setupData {
    self.cache = [NSMutableDictionary dictionary];
}

- (void)cache:(QNZonesInfo *)zonesInfo forKey:(NSString *)cacheKey {
    if (!cacheKey || [cacheKey isEqualToString:@""] || zonesInfo == nil) {
        return;
    }

    @synchronized (self) {
        // 1. 查缓存是否已经处理，已处理不再次处理
        QNZonesInfo *oldZonesInfo = self.cache[cacheKey];
        if (oldZonesInfo != nil && [zonesInfo.buildDate timeIntervalSince1970] == [oldZonesInfo.buildDate timeIntervalSince1970]) {
            return;
        }
        
        // 2. 写内存缓存
        self.cache[cacheKey] = zonesInfo;
        
        // 3. 写磁盘缓存，临时 zone 不写
        if (!zonesInfo.isTemporary) {
            [[QNAutoZoneDiskCache share] cache:zonesInfo forKey:cacheKey];
        }
    }
}

- (QNZonesInfo *)cacheForKey:(NSString *)cacheKey {
    if (!cacheKey || [cacheKey isEqualToString:@""]) {
        return nil;
    }

    QNZonesInfo *zonesInfo = nil;
    @synchronized (self) {
        // 1. 内存缓存取
        zonesInfo = self.cache[cacheKey];
        if (zonesInfo != nil) {
            return zonesInfo;
        }
        
        // 2. 磁盘缓存取
        zonesInfo = [[QNAutoZoneDiskCache share] cacheForKey:cacheKey];
        
        // 3. 取到写内存
        if (zonesInfo != nil) {
            self.cache[cacheKey] = zonesInfo;
        }
    }

    return zonesInfo;
}

- (void)clearCache {
    @synchronized (self) {
        for (NSString *key in self.cache.allKeys) {
            QNZonesInfo *info = self.cache[key];
            [info toTemporary];
        }
        
        [[QNAutoZoneDiskCache share] clearCache];
    }
}

@end

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

+ (void)clearCache {
    [[QNAutoZoneCache share] clearCache];
}

- (instancetype)init {
    if (self = [super init]) {
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
    QNZonesInfo *zonesInfo = [[QNAutoZoneCache share] cacheForKey:cacheKey];
    zonesInfo = [zonesInfo copy];
    return zonesInfo;
}

- (void)preQuery:(QNUpToken *)token on:(QNPrequeryReturn)ret {

    if (token == nil || ![token isValid]) {
        ret(-1, [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"], nil);
        return;
    }

    QNUploadRegionRequestMetrics *cacheMetrics = [QNUploadRegionRequestMetrics emptyMetrics];
    [cacheMetrics start];

    NSString *cacheKey = [self makeCacheKey:token.index];
    QNZonesInfo *zonesInfo = [[QNAutoZoneCache share] cacheForKey:cacheKey];

    // 临时的 zonesInfo 仅能使用一次
    if (zonesInfo != nil && zonesInfo.isValid && !zonesInfo.isTemporary) {
        [cacheMetrics end];
        ret(0, [QNResponseInfo successResponse], cacheMetrics);
        return;
    }

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
        QNResponseInfo *responseInfo = [(QNUCQuerySingleFlightValue *) value responseInfo];
        NSDictionary *response = [(QNUCQuerySingleFlightValue *) value response];
        QNUploadRegionRequestMetrics *metrics = [(QNUCQuerySingleFlightValue *) value metrics];

        if (responseInfo && responseInfo.isOK) {
            QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:response];
            if ([zonesInfo isValid]) {
                [[QNAutoZoneCache share] cache:zonesInfo forKey:cacheKey];
                ret(0, responseInfo, metrics);
            } else {
                ret(-11, responseInfo, metrics);
            }
        } else {
            QNZonesInfo *info = nil;
            if (self.defaultZone != nil) {
                QNZonesInfo *infoP = [self.defaultZone getZonesInfoWithToken:token];
                if (infoP && [infoP isValid]) {
                    [infoP toTemporary];
                    info = infoP;
                }
                [[QNAutoZoneCache share] cache:info forKey:cacheKey];
                ret(0, responseInfo, metrics);
            } else if (zonesInfo != nil) {
                // 缓存有，但是失效也可使用
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
