//
//  QNPHAssetFile.h
//  QiniuSDK
//
//  Created by su xinde on 15/10/22.
//  Copyright © 2015年 Su XinDe. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QNFileDelegate.h"

@class PHAsset;

@interface QNPHAssetFile : NSObject <QNFileDelegate>

/**
 *    打开指定文件
 *
 *    @param path      文件路径
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAsset *)asset
               error:(NSError *__autoreleasing *)error;

@end
