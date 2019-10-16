//
//  QNConcurrentResumeUpload.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/7/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNHttpDelegate.h"
#import "QNUploadManager.h"
#import "QNFileDelegate.h"

@class QNUpToken;
@class QNUploadOption;
@class QNConfiguration;

@interface QNConcurrentResumeUpload : NSObject

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                     withKey:(NSString *)key
                   withToken:(QNUpToken *)token
                withRecorder:(id<QNRecorderDelegate>)recorder
             withRecorderKey:(NSString *)recorderKey
             withHttpManager:(id<QNHttpDelegate>)http
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
           withConfiguration:(QNConfiguration *)config;

- (void)run;

@end
