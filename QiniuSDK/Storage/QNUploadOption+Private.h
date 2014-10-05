//
//  QNUploadOption+Private.h
//  QiniuSDK
//
//  Created by bailong on 14/10/5.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadOption.h"

@interface QNUploadOption (Private)

- (NSDictionary *)p_convertToPostParams;

- (BOOL)isCancelled;
@end
