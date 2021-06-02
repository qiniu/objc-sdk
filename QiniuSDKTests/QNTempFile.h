//
//  QNTempFile.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QNInputStream.h"

typedef NS_ENUM(NSInteger, QNTempFileType) {
    QNTempFileTypeNone = 0,
    QNTempFileTypeData,
    QNTempFileTypeFile,
    QNTempFileTypeStream,
    QNTempFileTypeStreamNoSize,
};

@interface QNTempFile : NSObject

@property(nonatomic, assign)BOOL canRemove;
@property(nonatomic, assign)long long size;
@property(nonatomic, strong)NSURL *fileUrl;
@property(nonatomic,  copy, readonly)NSString *fileHash;
@property(nonatomic, strong, readonly)NSInputStream *inputStream;
@property(nonatomic, strong, readonly)NSData *data;

@property(nonatomic, assign)QNTempFileType fileType;

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
