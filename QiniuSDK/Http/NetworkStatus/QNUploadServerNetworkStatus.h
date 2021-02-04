//
//  QNUploadServerNetworkStatus.h
//  QiniuSDK
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QNUploadServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadServerNetworkStatus : NSObject

+ (QNUploadServer *)getBetterNetworkServer:(QNUploadServer *)serverA
                                   serverB:(QNUploadServer *)serverB;

+ (BOOL)isServerNetworkBetter:(QNUploadServer *)serverA
                  thanServerB:(QNUploadServer *)serverB;

@end

NS_ASSUME_NONNULL_END
