//
//  QNUploadRequestState.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadRequestState : NSObject

// old server 不验证tls sni
@property(nonatomic, assign)BOOL isUseOldServer;

// 是否使用HTTP3
@property(atomic, assign)BOOL isHTTP3;

// 用户是否取消
@property(atomic, assign)BOOL isUserCancel;

@end

NS_ASSUME_NONNULL_END
