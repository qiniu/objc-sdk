//
//  QNUploadServerDomainResolver.m
//  AppTest
//
//  Created by yangsen on 2020/4/23.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNUploadDomainRegion.h"
#import "QNUploadServer.h"
#import "QNZoneInfo.h"
#import "QNUploadServerFreezeManager.h"
#import "QNDnsPrefetcher.h"

@interface QNUploadIpGroup : NSObject
@property(nonatomic,   copy)NSString *groupType;
@property(nonatomic, strong)NSArray <NSString *> *ipList;
@end
@implementation QNUploadIpGroup
@end

@interface QNUploadServerDomain: NSObject
@property(atomic   , assign)BOOL isAllFreezed;
@property(nonatomic,   copy)NSString *host;
@property(nonatomic, strong)NSArray <NSString *> *ipList;
@end
@implementation QNUploadServerDomain
+ (QNUploadServerDomain *)domain:(NSString *)host{
    QNUploadServerDomain *domain = [[QNUploadServerDomain alloc] init];
    domain.host = host;
    domain.isAllFreezed = false;
    return domain;
}
- (QNUploadServer *)getServer{
    if (self.isAllFreezed || !self.host || self.host.length == 0) {
        return nil;
    }
    
    if (!self.ipList || self.ipList.count == 0) {
        NSMutableArray *ipList = [NSMutableArray array];
        NSArray *inetAddresses = [kQNDnsPrefetcher getInetAddressByHost:self.host];
        for (id <QNInetAddressDelegate> inetAddress in inetAddresses) {
            NSString *ipValue = inetAddress.ipValue;
            if (ipValue && ipValue.length > 0) {
                [ipList addObject:ipValue];
            }
        }
        self.ipList = ipList;
    }
    
    if (self.ipList && self.ipList.count > 0) {
        NSString *serverIp = nil;
        for (NSString *ip in self.ipList) {
            NSString *ipType = [self getIpType:ip];
            if (ipType && ![kQNUploadServerFreezeManager isFreezeHost:self.host type:ipType]) {
                serverIp = ip;
                break;
            }
        }
        if (serverIp != nil) {
            return [QNUploadServer server:self.host host:self.host ip:serverIp];
        } else {
            self.isAllFreezed = true;
            return nil;
        }
    } else if (![kQNUploadServerFreezeManager isFreezeHost:self.host type:nil]){
        return [QNUploadServer server:self.host host:self.host ip:nil];
    } else {
        self.isAllFreezed = true;
        return nil;
    }
}
- (void)freeze:(NSString *)ip{
    [kQNUploadServerFreezeManager freezeHost:self.host type:[self getIpType:ip]];
}
- (NSString *)getIpType:(NSString *)ip{
    NSString *type = nil;
    if ([ip containsString:@":"]) {
        type = @"ipv6";
    } else if ([ip containsString:@"."]){
        NSInteger firstNumber = [[ip componentsSeparatedByString:@"."].firstObject integerValue];
        if (firstNumber > 0 && firstNumber < 127) {
            type = @"ipv4-A";
        } else if (firstNumber > 127 && firstNumber <= 191) {
            type = @"ipv4-B";
        } else if (firstNumber > 191 && firstNumber <= 223) {
            type = @"ipv4-C";
        } else if (firstNumber > 223 && firstNumber <= 239) {
            type = @"ipv4-D";
        } else if (firstNumber > 239 && firstNumber < 255) {
            type = @"ipv4-E";
        }
    }
    return type;
}
@end


@interface QNUploadDomainRegion()
@property(atomic   , assign)BOOL isAllFreezed;
@property(nonatomic, strong)NSArray <NSString *> *domainHostList;
@property(nonatomic, strong)NSDictionary <NSString *, QNUploadServerDomain *> *domainDictionary;
@property(nonatomic, strong)NSArray <NSString *> *oldDomainHostList;
@property(nonatomic, strong)NSDictionary <NSString *, QNUploadServerDomain *> *oldDomainDictionary;

@property(nonatomic, strong, nullable)QNZoneInfo *zoneInfo;
@end
@implementation QNUploadDomainRegion

- (void)setupRegionData:(QNZoneInfo *)zoneInfo{
    _zoneInfo = zoneInfo;
    
    self.isAllFreezed = NO;
    NSMutableArray *serverGroups = [NSMutableArray array];
    NSMutableArray *domainHostList = [NSMutableArray array];
    if (zoneInfo.acc) {
        [serverGroups addObject:zoneInfo.acc];
        [domainHostList addObjectsFromArray:zoneInfo.acc.allHosts];
    }
    if (zoneInfo.src) {
        [serverGroups addObject:zoneInfo.src];
        [domainHostList addObjectsFromArray:zoneInfo.src.allHosts];
    }
    self.domainHostList = domainHostList;
    self.domainDictionary = [self createDomainDictionary:serverGroups];
    
    [serverGroups removeAllObjects];
    NSMutableArray *oldDomainHostList = [NSMutableArray array];
    if (zoneInfo.old_acc) {
        [serverGroups addObject:zoneInfo.old_acc];
        [oldDomainHostList addObjectsFromArray:zoneInfo.old_acc.allHosts];
    }
    if (zoneInfo.old_src) {
        [serverGroups addObject:zoneInfo.old_src];
        [oldDomainHostList addObjectsFromArray:zoneInfo.old_src.allHosts];
    }
    self.oldDomainHostList = oldDomainHostList;
    self.oldDomainDictionary = [self createDomainDictionary:serverGroups];
}
- (NSDictionary *)createDomainDictionary:(NSArray <QNUploadServerGroup *> *)serverGroups{
    NSMutableDictionary *domainDictionary = [NSMutableDictionary dictionary];
    
    for (QNUploadServerGroup *serverGroup in serverGroups) {
        for (NSString *host in serverGroup.allHosts) {
            QNUploadServerDomain *domain = [QNUploadServerDomain domain:host];
            [domainDictionary setObject:domain forKey:host];
        }
    }
    return [domainDictionary copy];
}

- (id<QNUploadServer>)getNextServer:(BOOL)isOldServer
                       freezeServer:(id<QNUploadServer>)freezeServer{
    if (self.isAllFreezed) {
        return nil;
    }
    
    if (freezeServer.serverId) {
        [_domainDictionary[freezeServer.serverId] freeze:freezeServer.ip];
        [_oldDomainDictionary[freezeServer.serverId] freeze:freezeServer.ip];
    }
    
    NSArray *hostList = isOldServer ? self.oldDomainHostList : self.domainHostList;
    NSDictionary *domainInfo = isOldServer ? self.oldDomainDictionary : self.domainDictionary;
    QNUploadServer *server = nil;
    for (NSString *host in hostList) {
        server = [domainInfo[host] getServer];
        if (server) {
           break;
        }
    }
    
    if (server == nil) {
        self.isAllFreezed = YES;
    }
    return server;
}
@end
