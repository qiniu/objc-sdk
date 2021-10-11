//
//  QNRequestClient.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestMetrics.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^QNRequestClientCompleteHandler)(NSURLResponse * _Nullable, QNUploadSingleRequestMetrics * _Nullable, NSData * _Nullable, NSError * _Nullable);

@protocol QNRequestClient <NSObject>

// client 标识
@property(nonatomic,  copy, readonly)NSString *clientId;

- (void)request:(NSURLRequest *)request
connectionProxy:(NSDictionary * _Nullable)connectionProxy
       progress:(void(^ _Nullable)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(QNRequestClientCompleteHandler)complete;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
