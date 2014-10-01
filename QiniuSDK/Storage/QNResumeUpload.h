//
//  QNResumeUpload.h
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#ifndef QiniuSDK_QNResumeUpload_h
#define QiniuSDK_QNResumeUpload_h

#import <Foundation/Foundation.h>
#import "../Http/QNHttpManager.h"

    @class QNUploadOption;

    @interface QNResumeUpload : NSObject

    - (instancetype)initWithData        :(NSData *)data
                    withSize            :(UInt32)size
                    withKey             :(NSString *)key
                    withToken           :(NSString *)token
                    withCompleteBlock   :(QNCompleteBlock)block
                    withOption          :(QNUploadOption *)option;

    - (NSError *)run;

    @end
#endif
