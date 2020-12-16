//
//  QNUploadOption.m
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import "QNUploadOption.h"
#import "QNUploadManager.h"

static NSString *mime(NSString *mimeType) {
    if (mimeType == nil || [mimeType isEqualToString:@""]) {
        return @"application/octet-stream";
    }
    return mimeType;
}

@implementation QNUploadOption

+ (NSDictionary *)filterParam:(NSDictionary *)params {
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if (params == nil) {
        return ret;
    }

    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        if ([key hasPrefix:@"x:"] && ![obj isEqualToString:@""]) {
            ret[key] = obj;
        } else {
            NSLog(@"参数%@设置无效，请检查参数格式", key);
        }
    }];

    return ret;
}

+ (NSDictionary *)filterMetaDataParam:(NSDictionary *)params {
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if (params == nil) {
        return ret;
    }

    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        if ([key hasPrefix:@"x-qn-meta-"] && ![obj isEqualToString:@""]) {
            ret[key] = obj;
        } else {
            NSLog(@"参数%@设置无效，请检查参数格式", key);
        }
    }];

    return ret;
}


- (instancetype)initWithProgressHandler:(QNUpProgressHandler)progress {
    return [self initWithMime:nil progressHandler:progress params:nil checkCrc:NO cancellationSignal:nil];
}

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(QNUpProgressHandler)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
          cancellationSignal:(QNUpCancellationSignal)cancel {
    return [self initWithMime:mimeType
              progressHandler:progress
                       params:params
               metaDataParams:nil
                     checkCrc:check
           cancellationSignal:cancel];
}

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(QNUpProgressHandler)progress
                      params:(NSDictionary *)params
              metaDataParams:(NSDictionary *)metaDataParams
                    checkCrc:(BOOL)check
          cancellationSignal:(QNUpCancellationSignal)cancellation{
    if (self = [super init]) {
        _mimeType = mime(mimeType);
        _progressHandler = progress != nil ? progress : ^(NSString *key, float percent) {};
        _params = [QNUploadOption filterParam:params];
        _metaDataParam = [QNUploadOption filterMetaDataParam:metaDataParams];
        _checkCrc = check;
        _cancellationSignal = cancellation != nil ? cancellation : ^BOOL() {
            return NO;
        };
    }

    return self;
}

+ (instancetype)defaultOptions {
    return [[QNUploadOption alloc] initWithMime:nil progressHandler:nil params:nil checkCrc:NO cancellationSignal:nil];
}

@end
