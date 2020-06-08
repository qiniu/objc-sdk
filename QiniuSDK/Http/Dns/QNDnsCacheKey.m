//
//  QNDnsCacheKey.m
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNDnsCacheKey.h"

@implementation QNDnsCacheKey

+ (instancetype)dnsCacheKey:(NSString *)currentTime
                    localIp:(NSString *)localIp{
    
    QNDnsCacheKey *key = [[QNDnsCacheKey alloc] init];
    key.currentTime = currentTime;
    key.localIp = localIp;
    return key;
}

+ (instancetype)dnsCacheKey:(NSString *)key{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *keyInfo = [NSJSONSerialization JSONObjectWithData:keyData options:NSJSONReadingMutableLeaves error:&error];
    return [QNDnsCacheKey dnsCacheKey:keyInfo[@"currentTime"]
                              localIp:keyInfo[@"localIp"]];
}

- (NSString *)toString{
    NSDictionary *keyInfo = @{@"currentTime" : self.currentTime ?: @"",
                              @"localIp" : self.localIp ?: @""};
    NSError *error;
    NSData *keyData = [NSJSONSerialization dataWithJSONObject:keyInfo options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];
}

@end
