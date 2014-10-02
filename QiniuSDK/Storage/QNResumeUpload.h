//
//  QNResumeUpload.h
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Http/QNHttpManager.h"

@class QNUploadOption;

@interface QNResumeUpload : NSObject

- (instancetype)initWithData:(NSData *)data
                    withSize:(UInt32)size
                     withKey:(NSString *)key
                   withToken:(NSString *)token
           withCompleteBlock:(QNCompleteBlock)block
                  withOption:(QNUploadOption *)option;

@property (nonatomic, readonly, copy) NSError *run;

@end
