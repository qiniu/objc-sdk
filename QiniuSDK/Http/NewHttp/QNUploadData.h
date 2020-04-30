//
//  QNUploadData.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadChunk : NSObject

// 当前chunk在block中的b偏移量
@property(nonatomic, assign, readonly)UInt32 offset;
// chunk crc用于做crc校验，无需校验时为空
@property(nonatomic,   copy, readonly)NSString *crc;
// chunk二进制流
@property(nonatomic, strong, readonly)NSData *info;

- (instancetype)initWithOffset:(UInt32)offset
                          info:(NSData *)info;
@end


@interface QNUploadBlock : NSObject

// block内所有分片
@property(nonatomic, strong, readonly)NSArray <QNUploadChunk *> * chunkList;
// block大小
@property(nonatomic, assign, readonly)UInt32 blockSize;
// block标识：块分片上传时的上下文信息
@property(nonatomic,   copy)NSString *context;

- (instancetype)initWithOffset:(NSArray <QNUploadChunk *> *)chunkList;

@end

NS_ASSUME_NONNULL_END
