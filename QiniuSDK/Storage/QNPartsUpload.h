//
//  QNPartsUpload.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/7.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNBaseUpload.h"
#import "QNUploadFileInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class QNRequestTransaction;
@interface QNPartsUpload : QNBaseUpload

@property(nonatomic, strong, readonly)QNResponseInfo *uploadDataErrorResponseInfo;
@property(nonatomic, strong, readonly)NSDictionary *uploadDataErrorResponse;

- (void)setErrorResponseInfo:(QNResponseInfo *)responseInfo
               errorResponse:(NSDictionary *)response;

- (BOOL)isAllUploaded;

- (void)serverInit:(void(^)(QNResponseInfo * _Nullable responseInfo,
                            NSDictionary * _Nullable response))completeHandler;

- (void)uploadNextDataCompleteHandler:(void(^)(BOOL stop,
                                               QNResponseInfo * _Nullable responseInfo,
                                               NSDictionary * _Nullable response))completeHandler;

- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo,
                                NSDictionary * _Nullable response))completeHandler;

@end

NS_ASSUME_NONNULL_END
