//
//  QNPHAssetResource.h
//  QiniuSDK
//
//  Created by   何舒 on 16/2/14.
//  Copyright © 2016年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QNFileDelegate.h"

@class PHAssetResource;
API_AVAILABLE(ios(9.0)) @interface QNPHAssetResource : NSObject <QNFileDelegate>

/**
 *    打开指定文件
 *
 *    @param phAssetResource      PHLivePhoto的PHAssetResource文件
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAssetResource *)phAssetResource
               error:(NSError *__autoreleasing *)error;

@end
