//
//  QNCacheTest.m
//  QiniuSDK
//
//  Created by yangsen on 2023/9/20.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import "QNCache.h"
#import <XCTest/XCTest.h>

@interface Info : NSObject <QNCacheObject>
@property (nonatomic,   copy)NSString *foo;
@property (nonatomic, assign)NSInteger bar;
@end
@implementation Info

- (nonnull id<QNCacheObject>)initWithDictionary:(nonnull NSDictionary *)dictionary {
    Info *info = [[Info alloc] init];
    info.foo = dictionary[@"foo"];
    info.bar = [dictionary[@"bar"] integerValue];
    return info;
}

- (nonnull NSDictionary *)toDictionary {
    return @{
        @"foo": self.foo,
        @"bar": @1
    };
}

@end

@interface QNCacheTest : XCTestCase

@end

@implementation QNCacheTest

- (void)testCache {
    Info *info = [[Info alloc] init];
    info.foo = @"foo";
    info.bar = 1;
    
    QNCacheOption *option = [[QNCacheOption alloc] init];
    option.version = @"v1";
    option.flushCount = 1;
    
    NSString *key = @"info_key";
    QNCache *cache = [QNCache cache:[Info class] option:option];
    [cache cache:info forKey:key atomically:true];
    
    // 1. 测试内存缓存
    Info *memInfo = (Info *)[cache cacheForKey:key];
    XCTAssert(memInfo == info, @"memory cache error");
    
    // 2. 测试删除内存缓存
    [cache clearMemoryCache];
    
    memInfo = (Info *)[cache cacheForKey:key];
    XCTAssert(memInfo == nil, @"clearMemoryCache error");
    
    // 3. 测试 load
    cache = [QNCache cache:[Info class] option:option];
    memInfo = (Info *)[cache cacheForKey:key];
    XCTAssert(memInfo != nil, @"load error");
    XCTAssert([memInfo.foo isEqualToString: info.foo], @"load error: foo");
    XCTAssert(memInfo.bar == info.bar, @"load error: bar");
    
    // 4. 测试清除磁盘缓存测试
    [cache clearDiskCache];
    cache = [QNCache cache:[Info class] option:option];
    memInfo = (Info *)[cache cacheForKey:key];
    XCTAssert(memInfo == nil, @"clearDiskCache error");
    
    
    // 5. 测试异步 flush
    [cache cache:info forKey:key atomically:false];
    
    [NSThread sleepForTimeInterval:3];
    
    cache = [QNCache cache:[Info class] option:option];
    memInfo = (Info *)[cache cacheForKey:key];
    XCTAssert(memInfo != nil, @"flush cache error");
    XCTAssert([memInfo.foo isEqualToString: info.foo], @"flush error: foo");
    XCTAssert(memInfo.bar == info.bar, @"flush error: bar");
}

@end
