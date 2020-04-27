//
//  QNResumeUpload.h
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNBaseUpload.h"
#import <Foundation/Foundation.h>
#import "QNFileDelegate.h"

@interface QNResumeUpload : QNBaseUpload

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                     withKey:(NSString *)key
                   withToken:(QNUpToken *)token
              withIdentifier:(NSString *)identifier
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
                withRecorder:(id<QNRecorderDelegate>)recorder
             withRecorderKey:(NSString *)recorderKey
             withSessionManager:(QNSessionManager *)sessionManager
           withConfiguration:(QNConfiguration *)config;

- (void)run;

@end
