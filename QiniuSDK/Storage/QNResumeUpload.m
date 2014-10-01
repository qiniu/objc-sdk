//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by bailong on 14/10/1.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNResumeUpload.h"
#import "QNUploadManager.h"
#import "../Common/QNBase64.h"

@interface QNResumeUpload ()

@property (nonatomic, strong) NSData            *data;
@property (nonatomic, weak) QNHttpManager       *httpManager;
@property UInt32                                size;
@property (nonatomic, strong) NSString          *key;
@property (nonatomic, strong) NSString          *token;
@property (nonatomic, strong) QNUploadOption    *option;
@property (nonatomic, strong) QNCompleteBlock   block;
@property (nonatomic, strong) NSArray           *contexts;

- (void)makeBlock   :(NSString *)uphost
        data        :(NSData *)data
        progress    :(QNProgressBlock)progressBlock
        complete    :(QNCompleteBlock)complete;

- (void)putChunk:(NSString *)uphost
        data    :(NSData *)data
        context :(NSString *)context
        offset  :(UInt32)offset
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete;

- (void)putBlock:(NSString *)uphost
        offset  :(UInt32)offset
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete;

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete;

@end

@implementation QNResumeUpload

- (instancetype)initWithData        :(NSData *)data
                withSize            :(UInt32)size
                withKey             :(NSString *)key
                withToken           :(NSString *)token
                withCompleteBlock   :(QNCompleteBlock)block
                withOption          :(QNUploadOption *)option
{
    if (self = [super init]) {
        self.data = data;
        self.size = size;
        self.key = key;
        self.token = token;
        self.option = option;
        self.block = block;
    }

    return self;
}

- (void)makeBlock   :(NSString *)uphost
        data        :(NSData *)data
        progress    :(QNProgressBlock)progressBlock
        complete    :(QNCompleteBlock)complete
{
    NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkblk/%d", uphost, (unsigned int)[data length]];

    [self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putChunk:(NSString *)uphost
        data    :(NSData *)data
        context :(NSString *)context
        offset  :(UInt32)offset
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete
{
    NSString *url = [[NSString alloc] initWithFormat:@"http://%@/bput/%@/%d", uphost, context, offset];

    // Todo: check crc
    [self post:url withData:data withCompleteBlock:complete withProgressBlock:progressBlock];
}

- (void)putBlock:(NSString *)uphost
        offset  :(UInt32)offset
        progress:(QNProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {}

- (void)makeFile:(NSString *)uphost
        complete:(QNCompleteBlock)complete
{
    NSString *mime;

    if (!self.option || !self.option.mimeType) {
        mime = @"";
    } else {
        mime = [[NSString alloc] initWithFormat:@"/mimetype/%@", [QNBase64 encode:self.option.mimeType]];
    }

    NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkfile/%u%@", uphost, self.size, mime];

    if (self.key != nil) {
        NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNBase64 encode:self.key]];
        url = [NSString stringWithFormat:@"%@%@", url, keyStr];
    }

    if (self.option && self.option.params) {
        NSEnumerator *e = [self.option.params keyEnumerator];

        for (id key = [e nextObject]; key != nil; key = [e nextObject]) {
            url = [NSString stringWithFormat:@"%@/%@/%@", url, key, [QNBase64 encode:[self.option.params objectForKey:key]]];
        }
    }

    NSMutableData   *postData = [NSMutableData data];
    NSString        *bodyStr = [self.contexts componentsJoinedByString:@","];
    [postData appendData:[bodyStr dataUsingEncoding:NSUTF8StringEncoding]];
    [self post:url withData:postData withCompleteBlock:complete withProgressBlock:nil];
}

- (void)post                :(NSString *)url
        withData            :(NSData *)data
        withCompleteBlock   :(QNCompleteBlock)completeBlock
        withProgressBlock   :(QNProgressBlock)progressBlock
{
    NSDictionary *headers = @{@"Authorization":self.token, @"Content-Type":@"application/octet-stream"};

    [self.httpManager post:url withData:data withParams:nil withHeaders:headers withCompleteBlock:completeBlock withProgressBlock:progressBlock];
}

- (NSError *)run
{
    return nil;
}

@end
