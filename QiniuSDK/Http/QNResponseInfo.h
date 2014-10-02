//
//  QNResponseInfo.h
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNResponseInfo : NSObject

@property int       stausCode;
@property NSString  *ReqId;
@property NSString  *xlog;
@property NSString  *remoteIp;
@property NSError   *error;

-(instancetype) initWithError:(NSError*) error;

-(instancetype) init:(int) status
 withReqId:(NSString *)reqId
  withXLog:(NSString *)xlog
withRemote:(NSString *)ip
 withBody:(id)body;

@end