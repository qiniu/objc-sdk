//
//  QNUploadInfoReporter.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@class QNResponseInfo;

#define kQNReporter [QNUploadInfoReporter sharedInstance]
@interface QNUploadInfoReporter : NSObject

- (id)init __attribute__((unavailable("Use sharedInstance: instead.")));
+ (instancetype)sharedInstance;

/**
*    上报统计信息
*
*    @param jsonString  需要记录的json字符串
*    @param token   上传凭证
*
*/
- (void)report:(NSString *)jsonString token:(NSString *)token;

/**
 *    清空统计信息
 */
- (void)clean;

@end

