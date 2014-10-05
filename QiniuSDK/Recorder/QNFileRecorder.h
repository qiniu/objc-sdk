//
//  QNFileRecorder.h
//  QiniuSDK
//
//  Created by bailong on 14/10/5.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNRecorderDelegate.h"

@interface QNFileRecorder : NSObject<QNRecorderDelegate>

-(instancetype) initWithFolder:(NSString *)directory;

@end
