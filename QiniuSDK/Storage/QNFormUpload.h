//
//  QNFormUpload.h
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNSessionManager.h"
#import "QNUpToken.h"
#import "QNUploadManager.h"
#import <Foundation/Foundation.h>

@interface QNFormUpload : NSObject

- (instancetype)initWithData:(NSData *)data
                     withKey:(NSString *)key
                withFileName:(NSString *)fileName
                   withToken:(QNUpToken *)token
              withIdentifier:(NSString *)identifier
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
             withSessionManager:(QNSessionManager *)sessionManager
           withConfiguration:(QNConfiguration *)config;

- (void)put;

@end
