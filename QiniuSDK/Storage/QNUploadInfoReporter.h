//
//  QNUploadInfoReporter.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QNReportConfig;
@class QNResponseInfo;

@interface QNUploadInfoReporter : NSObject

- (id)init __attribute__((unavailable("Use initWithReportConfiguration: instead.")));

- (instancetype)initWithReportConfiguration:(QNReportConfig *)config;

- (void)recordWithUploadResult:(NSString *)result uploadToken:(NSString *)token;

@end
