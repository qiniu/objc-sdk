//
//  QNCache.m
//  QiniuSDK
//
//  Created by yangsen on 2023/9/20.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import "QNCache.h"
#import "QNAsyncRun.h"
#import "QNUtils.h"
#import "QNFileRecorder.h"

@implementation QNCacheOption
- (instancetype)init {
    if (self = [super init]) {
        self.flushCount = 1;
    }
    return self;
}

- (NSString *)version {
    if (_version == nil || _version.length == 0) {
        _version = @"v1.0.0";
    }
    return _version;
}
@end

@interface QNCache()

@property (nonatomic, strong) Class objectClass;
@property (nonatomic, strong) QNCacheOption *option;
@property (nonatomic, strong) QNFileRecorder *diskCache;
@property (nonatomic, assign) BOOL isFlushing;
@property (nonatomic, assign) int needFlushCount;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id <QNCacheObject>> *memCache;

@end
@implementation QNCache

+ (instancetype)cache:(Class)objectClass option:(QNCacheOption *)option {
    QNCache *cache = [[QNCache alloc] init];
    cache.objectClass = objectClass;
    cache.option = option ? option : [[QNCacheOption alloc] init];
    cache.isFlushing = false;
    cache.needFlushCount = 0;
    cache.memCache = [[NSMutableDictionary alloc] init];
    NSString *path = [[QNUtils sdkCacheDirectory] stringByAppendingFormat:@"/%@", objectClass];
    cache.diskCache = [QNFileRecorder fileRecorderWithFolder:path error:nil];
    [cache load];
    return cache;
}

- (void)load {
    if (![self.objectClass conformsToProtocol:@protocol(QNCacheObject)]) {
        return;
    }
    
    NSData *data = nil;
    @synchronized (self) {
        data = [self.diskCache get:self.option.version];
    }
    if (data == nil) {
        return;
    }
    
    NSError *error = nil;
    NSDictionary *cacheDict = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableLeaves
                                                                error:&error];
    if (error != nil || cacheDict == nil || cacheDict.count == 0) {
        [self.diskCache del:self.option.version];
        return;
    }
    
    NSMutableDictionary<NSString *, id<QNCacheObject>> *cache = [NSMutableDictionary dictionary];
    for (NSString *key in cacheDict.allKeys) {
        NSDictionary *objectDict = cacheDict[key];
        if (!objectDict || objectDict.count == 0) {
            continue;
        }
        
        id<QNCacheObject> object = [[self.objectClass alloc] initWithDictionary:objectDict];
        if (object != nil) {
            cache[key] = object;
        }
    }
    
    if (!cache || cache.count == 0) {
        [self.diskCache del:self.option.version];
        return;
    }
    
    @synchronized (self) {
        self.memCache = cache;
    }
}

- (NSDictionary<NSString *,id<QNCacheObject>> *)allMemoryCache {
    @synchronized (self) {
        return [self.memCache copy];
    }
}

- (void)cache:(id<QNCacheObject>)object forKey:(NSString *)cacheKey atomically:(BOOL)atomically {
    if (!cacheKey || [cacheKey isEqualToString:@""] || object == nil ||
        ![object isKindOfClass:self.objectClass]) {
        return;
    }
    
    @synchronized (self) {
        self.needFlushCount ++;
        self.memCache[cacheKey] = object;
    }
    
    if (self.needFlushCount >= self.option.flushCount) {
        [self flush:atomically];
    }
}

- (void)flush:(BOOL)atomically {
    @synchronized (self) {
        if (self.isFlushing) {
            return;
        }
        self.needFlushCount = 0;
        self.isFlushing = true;
    }
    
    NSDictionary<NSString *, id <QNCacheObject>> *flushCache = nil;
    @synchronized (self) {
        if (self.memCache == nil || self.memCache.count == 0) {
            return;
        }
        
        flushCache = [self.memCache copy];
    }
    
    if (atomically) {
        [self flushCache:flushCache];
    } else {
        QNAsyncRun(^{
            [self flushCache:flushCache];
        });
    }
}

- (void)flushCache:(NSDictionary <NSString *, id <QNCacheObject>> *)flushCache {
    if (flushCache == nil || flushCache.count == 0) {
        return;
    }
    
    NSMutableDictionary *flushDict = [NSMutableDictionary dictionary];
    for (NSString *key in flushCache.allKeys) {
        id <QNCacheObject> object = flushCache[key];
        if (![object respondsToSelector:@selector(toDictionary)]) {
            continue;
        }
        flushDict[key] = [object toDictionary];
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:flushDict options:NSJSONWritingPrettyPrinted error:nil];
    if (!data || data.length == 0) {
        return;
    }
    
    [self.diskCache set:self.option.version data:data];
    
    @synchronized (self) {
        self.isFlushing = false;
    }
}

- (id <QNCacheObject>)cacheForKey:(NSString *)cacheKey {
    @synchronized (self) {
        return [self.memCache valueForKey:cacheKey];
    }
}

- (void)clearMemoryCache {
    @synchronized (self) {
        self.memCache = [NSMutableDictionary dictionary];
    }
}

- (void)clearDiskCache {
    @synchronized (self) {
        [self.diskCache deleteAll];
    }
}

@end
