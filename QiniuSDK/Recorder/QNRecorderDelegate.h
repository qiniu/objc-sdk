//
//  QNRecorderDelegate.h
//  QiniuSDK
//
//  Created by bailong on 14/10/5.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol QNRecorderDelegate <NSObject>

- (NSError *)set:(NSString *)key
            data:(NSData *)value;

- (NSData *)get:(NSString *)key;

- (NSError *)del:(NSString *)key;

@end
