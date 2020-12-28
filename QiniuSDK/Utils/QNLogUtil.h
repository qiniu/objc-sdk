//
//  QNLogUtil.h
//  QiniuSDK
//
//  Created by yangsen on 2020/12/25.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNLogUtil : NSObject

+ (void)setLogLevel:(int)level;

+ (void)log:(int)level
       file:(NSString *)file
   function:(NSString *)function
       line:(NSUInteger)line
     format:(NSString *)format, ...;


@end

NS_ASSUME_NONNULL_END
