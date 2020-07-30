//
//  QNInetAddress.m
//  QiniuSDK
//
//  Created by 杨森 on 2020/7/27.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNInetAddress.h"

@interface QNInetAddress()
@end
@implementation QNInetAddress
+ (instancetype)inetAddress:(id)addressInfo{
    
    NSDictionary *addressDic = nil;
    if ([addressInfo isKindOfClass:[NSDictionary class]]) {
        addressDic = (NSDictionary *)addressInfo;
    } else if ([addressInfo isKindOfClass:[NSString class]]){
        NSData *data = [(NSString *)addressInfo dataUsingEncoding:NSUTF8StringEncoding];
        addressDic = [NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableLeaves
                                                       error:nil];
    } else if ([addressInfo isKindOfClass:[NSData class]]) {
        addressDic = [NSJSONSerialization JSONObjectWithData:(NSData *)addressInfo
                                                     options:NSJSONReadingMutableLeaves
                                                       error:nil];
    } else if ([addressInfo conformsToProtocol:@protocol(QNIDnsNetworkAddress)]){
        id <QNIDnsNetworkAddress> address = (id <QNIDnsNetworkAddress> )addressInfo;
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        if ([address respondsToSelector:@selector(hostValue)] && [address hostValue]) {
            dic[@"hostValue"] = [address hostValue];
        }
        if ([address respondsToSelector:@selector(ipValue)] && [address ipValue]) {
            dic[@"ipValue"] = [address ipValue];
        }
        if ([address respondsToSelector:@selector(ttlValue)] && [address ttlValue]) {
            dic[@"ttlValue"] = [address ttlValue];
        }
        if ([address respondsToSelector:@selector(timestampValue)] && [address timestampValue]) {
            dic[@"timestampValue"] = [address timestampValue];
        }
        addressDic = [dic copy];
    }
    
    if (addressDic) {
        QNInetAddress *address = [[QNInetAddress alloc] init];
        [address setValuesForKeysWithDictionary:addressDic];
        return address;
    } else {
        return nil;
    }
}

- (BOOL)isValid{
    if (!self.timestampValue || !self.ipValue || self.ipValue.length == 0) {
        return NO;
    }
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    if (currentTimestamp > self.timestampValue.doubleValue + self.ttlValue.doubleValue) {
        return NO;
    } else {
        return YES;
    }
}

- (NSString *)toJsonInfo{
    NSString *defaultString = @"{}";
    NSDictionary *infoDic = [self toDictionary];
    if (!infoDic) {
        return defaultString;
    }
    
    NSData *infoData = [NSJSONSerialization dataWithJSONObject:infoDic
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    if (!infoData) {
        return defaultString;
    }
    
    NSString *infoStr = [[NSString alloc] initWithData:infoData encoding:NSUTF8StringEncoding];
    if (!infoStr) {
        return defaultString;
    } else {
        return infoStr;
    }
}

- (NSDictionary *)toDictionary{
    return [self dictionaryWithValuesForKeys:@[@"ipValue", @"hostValue", @"ttlValue", @"timestampValue"]];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{}

@end
