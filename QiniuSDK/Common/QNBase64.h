//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNBase64 : NSObject

+ (NSString *)encodeString:(NSString *)source;
+ (NSString *)encodeData:(NSData *)source;
//+ (NSData *)decodeString:(NSData *)source
//                   error:(NSError **)error;
@end
