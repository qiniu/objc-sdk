//
//  QNUploadOption.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^QNUpProgressBlock)(NSString *key, float percent);
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

- (instancetype)initWithProgess:(QNUpProgressBlock)progress;

- (NSDictionary *)p_convertToPostParams;

- (BOOL)isCancelled;
@end
