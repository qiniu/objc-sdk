//
//  QNErrorCode.h
//  QiniuSDK
//
//  Created by yangsen on 2020/10/21.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *    中途取消的状态码
 */
extern const int kQNRequestCancelled;

/**
 *    网络错误状态码
 */
extern const int kQNNetworkError;

/**
 *    错误参数状态码
 */
extern const int kQNInvalidArgument;

/**
 *    0 字节文件或数据
 */
extern const int kQNZeroDataSize;

/**
 *    错误token状态码
 */
extern const int kQNInvalidToken;

/**
 *    读取文件错误状态码
 */
extern const int kQNFileError;

/**
 *    本地 I/O 错误
 */
extern const int kQNLocalIOError;

/**
 *    ⽤户劫持错误 错误
 */
extern const int kQNMaliciousResponseError;
