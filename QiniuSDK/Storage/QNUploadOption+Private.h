//
//  QNUploadOption+Private.h
//  QiniuSDK
//
//  Created by bailong on 14/10/5.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadOption.h"

@interface QNUploadOption (Private)

@property (nonatomic, readonly, copy) NSDictionary *p_convertToPostParams;

@property (nonatomic, getter = isCancelled, readonly) BOOL cancelled;
@end
