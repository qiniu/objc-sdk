//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QNResponseInfo;
@class QNUploadOption;

typedef void (^QNUpCompleteBlock)(QNResponseInfo *info, NSString *key, NSDictionary *resp);

@interface QNUploadManager : NSObject

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompleteBlock)block
         option:(QNUploadOption *)option;

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompleteBlock)block
         option:(QNUploadOption *)option;

@end
