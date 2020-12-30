//
//  QNTempFile.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNTempFile : NSObject

@property(nonatomic, assign)BOOL canRemove;
@property(nonatomic, assign)long long size;
@property(nonatomic, strong)NSURL *fileUrl;
@property(nonatomic,  copy, readonly)NSString *fileHash;

+ (QNTempFile *)createTempFileWithSize:(int)size;
+ (QNTempFile *)createTempFileWithSize:(int)size
                                  name:(NSString *)name;

// identifier相同，文件内容则相同
+ (QNTempFile *)createTempFileWithSize:(int)size
                            identifier:(NSString *)identifier;
+ (QNTempFile *)createTempFileWithSize:(int)size
                                  name:(NSString *)name
                            identifier:(NSString *)identifier;

- (void)remove;

@end
