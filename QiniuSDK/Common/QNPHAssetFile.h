//
//  QNPHAssetFile.h
//  Pods
//
//  Created by   何舒 on 15/10/21.
//
//

#import <Foundation/Foundation.h>

#import "QNFileDelegate.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
@class PHAsset;
@interface QNPHAssetFile : NSObject<QNFileDelegate>
/**
 *    打开指定文件
 *
 *    @param path      文件路径
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAsset *)phAsset
               error:(NSError *__autoreleasing *)error;
@end
#endif
