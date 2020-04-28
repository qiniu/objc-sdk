//
//  QNDnsCacheKey.h
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNDnsCacheKey : NSObject

/// 缓存时间戳
@property(nonatomic,  copy)NSString *currentTime;
/// 缓存时本地IP
@property(nonatomic,  copy)NSString *localIp;

//MARK: -- 构造方法
+ (instancetype)dnsCacheKey:(NSString *)currentTime
                    localIp:(NSString *)localIp;
/// 根据key解析对象
/// @param key  key的构造方法可参考本对象方法toString
+ (instancetype)dnsCacheKey:(NSString *)key;


/// 转化字符串 可作为文件名
- (NSString *)toString;

@end

NS_ASSUME_NONNULL_END
