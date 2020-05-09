//
//  QNUploadRegion.h
//  QiniuSDK
//
//  Created by yangsen on 2020/5/9.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadDomainRegion.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadFixedHostRegion : QNUploadDomainRegion

+ (instancetype)fixedHostRegionWithHosts:(NSArray <NSString *> *)hosts;

@end

NS_ASSUME_NONNULL_END
