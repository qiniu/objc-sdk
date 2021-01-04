//
//  QNSingleFlight.h
//  QiniuSDK
//
//  Created by yangsen on 2021/1/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^QNSingleFlightComplete)(id _Nullable value, NSError * _Nullable error);
typedef void(^QNSingleFlightAction)(QNSingleFlightComplete _Nonnull complete);

@interface QNSingleFlight : NSObject

- (void)perform:(NSString * _Nullable)key
         action:(QNSingleFlightAction _Nonnull)action
       complete:(QNSingleFlightComplete _Nullable)complete;

@end

NS_ASSUME_NONNULL_END
