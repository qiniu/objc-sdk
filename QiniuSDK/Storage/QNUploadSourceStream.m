//
//  QNUploadSourceStream.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadSourceStream.h"

@interface QNUploadSourceStream()

@property(nonatomic, strong)NSInputStream *stream;

@end
@implementation QNUploadSourceStream

+ (instancetype)stream:(NSInputStream *)stream {
    QNUploadSourceStream *sourceStream = [[QNUploadSourceStream alloc] init];
    sourceStream.stream = stream;
    return sourceStream;
}

@end
