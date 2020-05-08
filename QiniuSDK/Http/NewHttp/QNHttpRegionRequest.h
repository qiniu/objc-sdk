//
//  QNHttpRequest.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadRegion.h"

NS_ASSUME_NONNULL_BEGIN


@class QNUploadRequstState, QNResponseInfo, QNConfiguration, QNUploadOption;

@interface QNHttpRegionRequest : NSObject

@property(nonatomic, strong, readonly)QNConfiguration *config;
@property(nonatomic, strong, readonly)QNUploadOption *uploadOption;


- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                        region:(id <QNUploadRegion>)region
                  requestState:(QNUploadRequstState *)requestState;


- (void)get:(NSString * _Nullable)action
    headers:(NSDictionary * _Nullable)headers
shouldRetry:(BOOL(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
   complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

- (void)post:(NSString * _Nullable)action
     headers:(NSDictionary * _Nullable)headers
        body:(NSData * _Nullable)body
 shouldRetry:(BOOL(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))shouldRetry
    progress:(void(^_Nullable)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
    complete:(void(^)(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response))complete;

@end

NS_ASSUME_NONNULL_END
