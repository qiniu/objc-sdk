//
//  QNUploadData.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadData.h"
#import "QNCrc32.h"

@interface QNUploadChunk()

@property(nonatomic,assign)UInt32 offset;
@property(nonatomic,  copy)NSString *crc;
@property(nonatomic, strong)NSData *info;

@end
@implementation QNUploadChunk

- (instancetype)initWithOffset:(UInt32)offset info:(NSData *)info{
    if (self = [super init]) {
        _offset = offset;
        _info = info;
        _crc = [NSString stringWithFormat:@"%u", (unsigned int)[QNCrc32 data:info]];
    }
    return self;
}
@end


@interface QNUploadBlock()

@property(nonatomic, strong)NSArray <QNUploadChunk *> *chunkList;
@property(nonatomic, assign)UInt32 blockSize;

@end
@implementation QNUploadBlock : NSObject

- (instancetype)initWithOffset:(NSArray <QNUploadChunk *> *)chunkList{
    if (self = [super init]) {
        _chunkList = chunkList;
    }
    return self;
}

@end
