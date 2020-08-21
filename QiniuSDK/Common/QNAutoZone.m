//
//  QNAutoZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNAutoZone.h"
#import "QNSessionManager.h"
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
    
    QNZonesInfo *zonesInfo = [QNZonesInfo buildZonesInfoWithResp:zonesInfoDic];
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

@implementation QNAutoZone {
    NSString *server;
    NSMutableDictionary *cache;
    NSLock *lock;
    QNSessionManager *sesionManager;
}

- (instancetype)init{
    if (self = [super init]) {
        server = @"https://uc.qbox.me";
        cache = [NSMutableDictionary new];
        lock = [NSLock new];
        sesionManager = [[QNSessionManager alloc] initWithProxy:nil timeout:10 urlConverter:nil];
    }
    return self;
}

- (NSString *)up:(QNUpToken *)token
    zoneInfoType:(QNZoneInfoType)zoneInfoType
         isHttps:(BOOL)isHttps
    frozenDomain:(NSString *)frozenDomain {

    NSString *index = [token index];
    [lock lock];
    QNZonesInfo *zonesInfo = [cache objectForKey:index];
    [lock unlock];
    if (zonesInfo == nil) {
        return nil;
    }
    return  [self upHost:[zonesInfo getZoneInfoWithType:zoneInfoType] isHttps:isHttps lastUpHost:frozenDomain];
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    if (token == nil) return nil;
    [lock lock];
    QNZonesInfo *zonesInfo = [cache objectForKey:[token index]];
    [lock unlock];
    return zonesInfo;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    
    if (token == nil) {
        ret(-1, nil);
        return;
    }
    
    [lock lock];
    QNZonesInfo *zonesInfo = [cache objectForKey:[token index]];
    [lock unlock];
    
    if (zonesInfo == nil) {
        zonesInfo = [[QNAutoZoneCache share] zonesInfoForToken:token];
        [self->lock lock];
        [self->cache setValue:zonesInfo forKey:[token index]];
        [self->lock unlock];
    }
    
    if (zonesInfo != nil) {
        ret(0, nil);
        return;
    }

    //https://uc.qbox.me/v3/query?ak=T3sAzrwItclPGkbuV4pwmszxK7Ki46qRXXGBBQz3&bucket=if-pbl
    NSString *url = [NSString stringWithFormat:@"%@/v4/query?ak=%@&bucket=%@", server, token.access, token.bucket];
    [sesionManager get:url withHeaders:nil withCompleteBlock:^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        if (!httpResponseInfo.error) {
        
            QNZonesInfo *zonesInfo = [QNZonesInfo buildZonesInfoWithResp:respBody];
            if (httpResponseInfo == nil) {
                ret(kQNInvalidToken, httpResponseInfo);
            } else {
                [self->lock lock];
                [self->cache setValue:zonesInfo forKey:[token index]];
                [self->lock unlock];
                [[QNAutoZoneCache share] cache:respBody forToken:token];
                ret(0, httpResponseInfo);
            }
        } else {
            ret(kQNNetworkError, httpResponseInfo);
        }
    }];
}

@end
