//
//  QNURLProtocol.h
//  AppTest
//
//  Created by yangsen on 2020/4/7.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNURLProtocol : NSURLProtocol

+ (void)registerProtocol;

+ (void)unregisterProtocol;

@end


@interface NSURLSessionConfiguration(QNURLProtocol)

+ (NSURLSessionConfiguration *)qn_sessionConfiguration;

@end

NS_ASSUME_NONNULL_END
