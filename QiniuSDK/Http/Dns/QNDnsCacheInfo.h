//
//  QNDnsCacheKey.h
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNDnsCacheInfo : NSObject

/// 缓存时间戳
@property(nonatomic,  copy, readonly)NSString *currentTime;
/// 缓存时本地IP
@property(nonatomic,  copy, readonly)NSString *localIp;
/// 缓存信息
@property(nonatomic,  copy, readonly)NSDictionary *info;

//MARK: -- 构造方法
/// 根据json构造对象
/// @param jsonData json数据
+ (instancetype)dnsCacheInfo:(NSData *)jsonData;

/// 根据属性构造对象
/// @param currentTime 缓存时间戳
/// @param localIp 缓存时本地IP
/// @param info 缓存信息
+ (instancetype)dnsCacheInfo:(NSString *)currentTime
                     localIp:(NSString *)localIp
                        info:(NSDictionary *)info;


/// 转化Json数据
- (NSData *)jsonData;

@end

NS_ASSUME_NONNULL_END
