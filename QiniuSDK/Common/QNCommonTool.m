
//
//  QNCommonTool.m
//  QiniuSDK_Mac
//
//  Created by WorkSpace_Sun on 2019/7/18.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNCommonTool.h"

@implementation QNCommonTool

+ (NSString *)getRandomStringWithLength:(UInt32)length {
    
    char data[length];
    for (int x=0; x < length; data[x++] = (char)('A' + (arc4random_uniform(26))));
    NSString *randomStr = [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
    NSString *string = [NSString stringWithFormat:@"%@",randomStr];
    return string;
}

@end
