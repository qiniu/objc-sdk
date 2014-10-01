//
//  HttpManager.h
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNRequestInfo : NSObject

@property int stausCode;
@property NSString *remoteIp;
@property NSString *ReqId;
@property NSString *xlog;
@property NSError *error;

@end

typedef void (^QNProgressBlock)(float percent);
typedef void (^QNCompleteBlock)(QNRequestInfo* info, NSDictionary* resp);
typedef BOOL (^QNCancelBlock)(void);


@interface QNHttpManager : NSObject

- (NSError *)multipartPost: (NSString *)url
                  withData: (NSData *)data
                withParams: (NSDictionary *)params
              withFileName: (NSString *)key
              withMimeType: (NSString *)mime
         withCompleteBlock: (QNCompleteBlock) completeBlock
         withProgressBlock: (QNProgressBlock) progressBlock;

- (NSError *)post: (NSString *)url
                  withData: (NSData *)data
                withParams: (NSDictionary *)params
               withHeaders: (NSDictionary *)headers
         withCompleteBlock: (QNCompleteBlock) completeBlock
         withProgressBlock: (QNProgressBlock) progressBlock;

@end
