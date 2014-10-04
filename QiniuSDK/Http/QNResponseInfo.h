//
//  QNResponseInfo.h
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNResponseInfo : NSObject

@property (readonly) int stausCode;
@property (nonatomic, copy, readonly) NSString *reqId;
@property (nonatomic, copy, readonly) NSString *xlog;
@property (nonatomic, copy, readonly) NSError *error;
@property (nonatomic, readonly, getter = isCancel) BOOL cancel;

- (instancetype)initWithError:(NSError *)error;

- (instancetype)initWithCancel;

- (instancetype)init:(int)status
           withReqId:(NSString *)reqId
            withXLog:(NSString *)xlog
            withBody:(id)body;

@end
