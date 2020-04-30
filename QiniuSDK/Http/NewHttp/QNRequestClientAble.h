//
//  QNRequestClientAble.h
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNRequestTransactionAble <NSObject>

@end


@protocol QNRequestClientAble <NSObject>

- (void)request:(NSURLRequest *)request
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(void(^)(NSDictionary * _Nullable response, NSError * _Nullable error, id <QNRequestTransactionAble> transaction))complete;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
