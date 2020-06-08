//
//  QNZone.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/16.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNZone.h"
#import "QNUpToken.h"
#import "QNZoneInfo.h"

@implementation QNZone
- (NSString *)upHost:(QNZoneInfo *)zoneInfo
             isHttps:(BOOL)isHttps
          lastUpHost:(NSString *)lastUpHost {
    NSString *upHost = nil;
    NSString *upDomain = nil;

    // frozen domain
    if (lastUpHost) {
        NSString *upLastDomain = nil;
        if (isHttps) {
            upLastDomain = [lastUpHost substringFromIndex:8];
        } else {
            upLastDomain = [lastUpHost substringFromIndex:7];
        }
        [zoneInfo frozenDomain:upLastDomain];
    }

    //get backup domain
    for (NSString *backupDomain in zoneInfo.upDomainsList) {
        NSDate *frozenTill = zoneInfo.upDomainsDic[backupDomain];
        NSDate *now = [NSDate date];
        if ([frozenTill compare:now] == NSOrderedAscending) {
            upDomain = backupDomain;
            break;
        }
    }
    if (upDomain) {
        [zoneInfo.upDomainsDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:upDomain];
    } else {
        
        //reset all the up host frozen time
        if (!lastUpHost) {
            for (NSString *domain in zoneInfo.upDomainsList) {
                [zoneInfo.upDomainsDic setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:domain];
            }
            if (zoneInfo.upDomainsList.count > 0) {
                upDomain = zoneInfo.upDomainsList[0];
            }
        }
    }

    if (upDomain) {
        if (isHttps) {
            upHost = [NSString stringWithFormat:@"https://%@", upDomain];
        } else {
            upHost = [NSString stringWithFormat:@"http://%@", upDomain];
        }
    }
    return upHost;
}

- (NSString *)up:(QNUpToken *)token
    zoneInfoType:(QNZoneInfoType)zoneInfoType
         isHttps:(BOOL)isHttps
    frozenDomain:(NSString *)frozenDomain {
    return nil;
}

- (QNZonesInfo *)getZonesInfoWithToken:(QNUpToken *)token {
    return nil;
}

- (void)preQuery:(QNUpToken *)token
              on:(QNPrequeryReturn)ret {
    ret(0, nil);
}
@end
