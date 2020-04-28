//
//  NSObject+QNSwizzle.h
//  HappyDNS
//
//  Created by yangsen on 2020/4/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject(QNSwizzle)

/// swizzle 两个对象方法
/// @param selectorA 方法a的sel
/// @param selectorB 方法b的sel
+ (BOOL)qn_swizzleInstanceMethodsOfSelectorA:(SEL)selectorA
                                   selectorB:(SEL)selectorB;

/// swizzle 两个类方法
/// @param selectorA 方法a的sel
/// @param selectorB 方法b的sel
+ (BOOL)qn_swizzleClassMethodsOfSelectorA:(SEL)selectorA
                                selectorB:(SEL)selectorB;

@end

NS_ASSUME_NONNULL_END
