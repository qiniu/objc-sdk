//
//  NSObject+QNSwizzle.m
//  HappyDNS
//
//  Created by yangsen on 2020/4/13.
//

#import "NSObject+QNSwizzle.h"
#import <objc/runtime.h>

@implementation NSObject(QNSwizzle)

+ (BOOL)qn_swizzleInstanceMethodsOfSelectorA:(SEL)selectorA
                                   selectorB:(SEL)selectorB{
    
    Method methodA = class_getInstanceMethod(self, selectorA);
    Method methodB = class_getInstanceMethod(self, selectorB);
    if (!methodA || !methodB) {
        return NO;
    }
    
    class_addMethod(self,
                    selectorA,
                    class_getMethodImplementation(self, selectorA),
                    method_getTypeEncoding(methodA));
    
    class_addMethod(self,
                    selectorB,
                    class_getMethodImplementation(self, selectorB),
                    method_getTypeEncoding(methodB));
    
    method_exchangeImplementations(class_getInstanceMethod(self, selectorA),
                                   class_getInstanceMethod(self, selectorB));
    
    return YES;
}

+ (BOOL)qn_swizzleClassMethodsOfSelectorA:(SEL)selectorA
                                selectorB:(SEL)selectorB{
    
    Method methodA = class_getInstanceMethod(object_getClass(self), selectorA);
    Method methodB = class_getInstanceMethod(object_getClass(self), selectorB);
    if (!methodA || !methodB) {
        return NO;
    }
    
    class_addMethod(self,
                    selectorA,
                    class_getMethodImplementation(self, selectorA),
                    method_getTypeEncoding(methodA));
    
    class_addMethod(self,
                    selectorB,
                    class_getMethodImplementation(self, selectorB),
                    method_getTypeEncoding(methodB));
    
    method_exchangeImplementations(class_getInstanceMethod(self, selectorA),
                                   class_getInstanceMethod(self, selectorB));
    
    return YES;
}

@end
