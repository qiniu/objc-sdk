//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QNRecorderDelegate.h"

@class QNResponseInfo;
@class QNUploadOption;

typedef void (^QNUpCompletionHandler)(QNResponseInfo *info, NSString *key, NSDictionary *resp);
typedef NSString *(^QNRecorderKeyGenerator)(NSString *uploadKey, NSString *filePath);
@interface QNUploadManager : NSObject

- (instancetype)initWithRecorder:(id <QNRecorderDelegate> )recorder;

- (instancetype)initWithRecorder:(id <QNRecorderDelegate> )recorder
            recorderKeyGenerator:(QNRecorderKeyGenerator)recorderKeyGenerator;

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option;

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option;

@end
