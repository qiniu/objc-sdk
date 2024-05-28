//
//  QNUploadServerDomainResolver.h
//  AppTest
//
//  Created by yangsen on 2020/4/23.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class QNConfiguration;

@interface QNUploadDomainRegion : NSObject <QNUploadRegion>

- (instancetype)initWithConfig:(QNConfiguration *)config;

@end

NS_ASSUME_NONNULL_END
