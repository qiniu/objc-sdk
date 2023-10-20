//
//  QNCache.h
//  QiniuSDK
//
//  Created by yangsen on 2023/9/20.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNCacheObject <NSObject>

- (nullable NSDictionary *)toDictionary;

- (nonnull id <QNCacheObject>)initWithDictionary:(nullable NSDictionary *)dictionary;

@end


@interface QNCacheOption : NSObject

// 当 cache 修改数量到达这个值时，就会 flush，默认是 1
@property (nonatomic, assign) int flushCount;
// 缓存被持久化为一个文件，此文件的文件名为 version，version 默认为：v1.0.0
@property (nonatomic,   copy) NSString *version;

@end

@interface QNCache : NSObject

+ (instancetype)cache:(Class)objectClass option:(QNCacheOption *)option;

- (id <QNCacheObject>)cacheForKey:(NSString *)cacheKey;
- (void)cache:(id<QNCacheObject>)object forKey:(NSString *)cacheKey atomically:(BOOL)atomically;

- (NSDictionary <NSString *, id <QNCacheObject>> *)allMemoryCache;

- (void)flush:(BOOL)atomically;

- (void)clearMemoryCache;

- (void)clearDiskCache;

@end

NS_ASSUME_NONNULL_END
