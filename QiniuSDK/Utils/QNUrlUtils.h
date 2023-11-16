//
//  QNUrlUtils.h
//  QiniuSDK
//
//  Created by yangsen on 2023/11/16.
//  Copyright © 2023 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUrlUtils : NSObject

+ (NSString *)setHostScheme:(NSString *)host useHttps:(BOOL)useHttps;

@end

NS_ASSUME_NONNULL_END
