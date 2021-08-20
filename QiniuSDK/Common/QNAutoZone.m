//
//  QNAutoZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNAutoZone.h"
#import "QNConfig.h"
#import "QNRequestTransaction.h"
#import "QNZoneInfo.h"
#import "QNUpToken.h"
#import "QNResponseInfo.h"
#import "QNFixedZone.h"
#import "QNSingleFlight.h"
#import "QNUploadRequestMetrics.h"


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

- (void)cache:(NSDictionary *)zonesInfo forKey:(NSString *)cacheKey{
    
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

- (QNZonesInfo *)zonesInfoForKey:(NSString *)cacheKey{
    
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
    
    return [QNZonesInfo infoWithDictionary:zonesInfoDic];
}

@end

@interface QNUCQuerySingleFlightValue : NSObject

@property(nonatomic, strong)QNResponseInfo *responseInfo;
@property(nonatomic, strong)NSDictionary *response;
@property(nonatomic, strong)QNUploadRegionRequestMetrics *metrics;

@end
@implementation QNUCQuerySingleFlightValue
@end

@interface QNAutoZone()

@property(nonatomic, strong)NSArray *ucHosts;
@property(nonatomic, strong)NSMutableDictionary *cache;
@property(nonatomic, strong)NSLock *lock;
@property(nonatomic, strong)NSMutableArray <QNRequestTransaction *> *transactions;

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

- (instancetype)init{
    if (self = [super init]) {
        _cache = [NSMutableDictionary new];
        _lock = [NSLock new];
        _transactions = [NSMutableArray array];
    }
    return self;
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    if (token == nil) return nil;
    [self.lock lock];
    QNZonesInfo *zonesInfo = [_cache objectForKey:[token index]];
    [self.lock unlock];
    return zonesInfo;
}

- (void)preQuery:(QNUpToken *)token on:(QNPrequeryReturn)ret {
    
    if (token == nil || ![token isValid]) {
        ret(-1, [QNResponseInfo responseInfoWithInvalidToken:@"invalid token"], nil);
        return;
    }
    
    QNUploadRegionRequestMetrics *cacheMetrics = [QNUploadRegionRequestMetrics emptyMetrics];
    [cacheMetrics start];
    
    NSString *cacheKey = token.index;
    [_lock lock];
    QNZonesInfo *zonesInfo = [_cache objectForKey:cacheKey];
    [_lock unlock];
    
    if (zonesInfo == nil) {
        zonesInfo = [[QNAutoZoneCache share] zonesInfoForKey:cacheKey];
        if (zonesInfo && zonesInfo.isValid) {
            [self.lock lock];
            [self.cache setValue:zonesInfo forKey:cacheKey];
            [self.lock unlock];
        }
    }
    
    // 临时的 zonesInfo 仅能使用一次
    if (zonesInfo != nil && zonesInfo.isValid && !zonesInfo.isTemporary) {
        [cacheMetrics end];
        ret(0, [QNResponseInfo successResponse], cacheMetrics);
        return;
    }
    
    kQNWeakSelf;
    QNSingleFlight *singleFlight = [QNAutoZone UCQuerySingleFlight];
    [singleFlight perform:token.index action:^(QNSingleFlightComplete  _Nonnull complete) {
        kQNStrongSelf;
        QNRequestTransaction *transaction = [self createUploadRequestTransaction:token];
        
        kQNWeakSelf;
        kQNWeakObj(transaction);
        [transaction queryUploadHosts:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
            kQNStrongSelf;
            kQNStrongObj(transaction);
            
            QNUCQuerySingleFlightValue *value = [[QNUCQuerySingleFlightValue alloc] init];
            value.responseInfo = responseInfo;
            value.response = response;
            value.metrics = metrics;
            complete(value, nil);
            
            [self destroyUploadRequestTransaction:transaction];
        }];
        
    } complete:^(id  _Nullable value, NSError * _Nullable error) {
        kQNStrongSelf;
        
        QNResponseInfo *responseInfo = [(QNUCQuerySingleFlightValue *)value responseInfo];
        NSDictionary *response = [(QNUCQuerySingleFlightValue *)value response];
        QNUploadRegionRequestMetrics *metrics = [(QNUCQuerySingleFlightValue *)value metrics];

        if (responseInfo && responseInfo.isOK) {
            QNZonesInfo *zonesInfo = [QNZonesInfo infoWithDictionary:response];
            [self.lock lock];
            [self.cache setValue:zonesInfo forKey:cacheKey];
            [self.lock unlock];
            [[QNAutoZoneCache share] cache:response forKey:cacheKey];
            ret(0, responseInfo, metrics);
        } else {
            if (responseInfo.isConnectionBroken) {
                ret(kQNNetworkError, responseInfo, metrics);
            } else {
                QNZonesInfo *zonesInfo = [[QNFixedZone localsZoneInfo] getZonesInfoWithToken:token];
                [self.lock lock];
                [self.cache setValue:zonesInfo forKey:cacheKey];
                [self.lock unlock];
                ret(0, responseInfo, metrics);
            }
        }
    }];
}

- (QNRequestTransaction *)createUploadRequestTransaction:(QNUpToken *)token{
    NSArray *hosts = nil;
    if (self.ucHosts && self.ucHosts.count > 0) {
        hosts = [self.ucHosts copy];
    } else {
        hosts = @[kQNPreQueryHost00, kQNPreQueryHost01];
    }
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:hosts
                                                                           regionId:QNZoneInfoEmptyRegionId
                                                                              token:token];
    [self.lock lock];
    [self.transactions addObject:transaction];
    [self.lock unlock];
    return transaction;
}

- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction{
    if (transaction) {
        [self.lock lock];
        [self.transactions removeObject:transaction];
        [self.lock unlock];
    }
}

@end
