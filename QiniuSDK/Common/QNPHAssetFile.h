//
//  QNPHAssetFile.h
//  Pods
//
//  Created by   何舒 on 15/10/21.
//
//

#import <Foundation/Foundation.h>

#import "QNFileDelegate.h"

API_AVAILABLE_BEGIN(ios(9.1))

@class PHAsset;
@interface QNPHAssetFile : NSObject <QNFileDelegate>
/**
 *    打开指定文件
 *
 *    @param phAsset      文件资源
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAsset *)phAsset
               error:(NSError *__autoreleasing *)error;
@end

API_AVAILABLE_END
