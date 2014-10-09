//
//  QNUploadOption.h
//  QiniuSDK
//
//  Created by bailong on 14/10/4.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^QNUpProgressHandler)(NSString *key, float percent);
typedef BOOL (^QNUpCancellationSignal)(void);

@interface QNUploadOption : NSObject

@property (copy, nonatomic, readonly) NSDictionary *params;
@property (copy, nonatomic, readonly) NSString *mimeType;
@property (readonly) BOOL checkCrc;
@property (copy, readonly) QNUpProgressHandler progressHandler;
@property (copy, readonly) QNUpCancellationSignal cancellationSignal;

- (instancetype)initWithMime:(NSString *)mimeType
             progressHandler:(QNUpProgressHandler)progress
                      params:(NSDictionary *)params
                    checkCrc:(BOOL)check
          cancellationSignal:(QNUpCancellationSignal)cancellation;

- (instancetype)initWithProgessHandler:(QNUpProgressHandler)progress;

@end
