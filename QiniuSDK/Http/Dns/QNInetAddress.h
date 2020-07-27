//
//  QNInetAddress.h
//  QiniuSDK
//
//  Created by 杨森 on 2020/7/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDns.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNInetAddress : NSObject <QNInetAddressDelegate>

@property(nonatomic,  copy)NSString *hostValue;
@property(nonatomic,  copy)NSString *ipValue;
@property(nonatomic, strong)NSNumber *ttlValue;
@property(nonatomic, strong)NSNumber *timestampValue;


/// 构造方法 addressData为json String / Dictionary / Data / 遵循 QNInetAddressDelegate的实例
+ (instancetype)inetAddress:(id)addressInfo;

/// 是否有效，根据时间戳判断
- (BOOL)isValid;

/// 对象转json
- (NSString *)toJsonInfo;

/// 对象转字典
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
