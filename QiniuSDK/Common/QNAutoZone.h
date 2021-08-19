//
//  QNAutoZone.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNAutoZone : QNZone

+ (instancetype)zoneWithUcHosts:(NSArray *)ucHosts;

@end

NS_ASSUME_NONNULL_END
