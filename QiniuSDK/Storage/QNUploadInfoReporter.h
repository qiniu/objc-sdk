//
//  QNUploadInfoReporter.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
@class QNReportConfig;

@interface QNUploadInfoReporter : NSObject

- (instancetype)initWithReportConfiguration:(QNReportConfig *)config;

@end
