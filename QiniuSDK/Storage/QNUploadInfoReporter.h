//
//  QNUploadInfoReporter.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define UploadInfoReporter [QNUploadInfoReporter sharedInstance]

@interface QNUploadInfoReporter : NSObject

@property (nonatomic, assign, readonly) NSTimeInterval lastReportTime;

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
 *    记录&上报统计信息
 *
 *    @param result  统计结果
 *    @param token  用户上传token
 *
 */
- (void)recordWithUploadResult:(NSString *)result uploadToken:(NSString *)token;

/**
 *    清空统计信息
 */
- (void)clean;

@end
