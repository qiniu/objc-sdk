//
//  QNCFHttpThreadPool.h
//  Qiniu
//
//  Created by yangsen on 2021/10/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QNCFHttpThread : NSThread

@property(nonatomic, assign, readonly)NSInteger operationCount;

@end


@interface QNCFHttpThreadPool : NSObject

@property(nonatomic, assign, readonly)NSInteger maxOperationPerThread;

+ (instancetype)shared;

- (QNCFHttpThread *)getOneThread;
- (void)addOperationCountOfThread:(QNCFHttpThread *)thread;
- (void)subtractOperationCountOfThread:(QNCFHttpThread *)thread;

@end

NS_ASSUME_NONNULL_END
