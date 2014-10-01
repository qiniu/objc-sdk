//
//  QNTask.h
//  QiniuSDK
//
//  Created by bailong on 14-9-29.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNRequestInfo : NSObject

@property int stausCode;
@property NSString *remoteIp;
@property NSString *ReqId;
@property NSError *error;

@end
