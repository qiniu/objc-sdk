//
//  QNTempFile.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNTempFile : NSObject

@property(nonatomic, strong)NSURL *fileUrl;
@property(nonatomic,  copy, readonly)NSString *fileHash;

+ (QNTempFile *)createTempfileWithSize:(int)size;
+ (QNTempFile *)createTempfileWithSize:(int)size
                                  name:(NSString *)name;

// identifier相同，文件内容则相同
+ (QNTempFile *)createTempfileWithSize:(int)size
                            identifier:(NSString *)identifier;
+ (QNTempFile *)createTempfileWithSize:(int)size
                                  name:(NSString *)name
                            identifier:(NSString *)identifier;

- (void)remove;

@end
