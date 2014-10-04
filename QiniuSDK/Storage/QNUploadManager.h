//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QNResponseInfo;

typedef void (^QNUpProgressBlock)(NSString *key, float percent);
typedef void (^QNUpCompleteBlock)(QNResponseInfo *info, NSString *key, NSDictionary *resp);
typedef BOOL (^QNUpCancelBlock)(void);

@interface QNUploadOption : NSObject

@property (copy, nonatomic, readonly) NSDictionary *params;
@property (copy, nonatomic, readonly) NSString *mimeType;
@property (readonly) BOOL checkCrc;
@property (copy, readonly) QNUpProgressBlock progress;
@property (copy, readonly) QNUpCancelBlock cancelToken;

- (instancetype)initWithMime:(NSString *)mimeType
                    progress:(QNUpProgressBlock)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
                 cancelToken:(QNUpCancelBlock)cancelBlock;
@end

@interface QNUploadManager : NSObject

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompleteBlock)block
         option:(QNUploadOption *)option;

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompleteBlock)block
         option:(QNUploadOption *)option;

@end
