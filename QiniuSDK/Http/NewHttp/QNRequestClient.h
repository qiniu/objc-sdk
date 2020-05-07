//
//  QNRequestClient.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNRequestClient <NSObject>

- (void)request:(NSURLRequest *)request
connectionProxy:(NSDictionary * _Nullable)connectionProxy
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(void(^)(NSURLResponse * _Nullable response, NSData * _Nullable responseData, NSError * _Nullable error))complete;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
