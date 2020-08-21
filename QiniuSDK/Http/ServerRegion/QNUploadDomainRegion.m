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
#import "QNDnsPrefetch.h"
#import "QNUtils.h"

@interface QNUploadIpGroup : NSObject
@property(nonatomic,   copy, readonly)NSString *groupType;
@property(nonatomic, strong, readonly)NSArray <id <QNIDnsNetworkAddress> > *ipList;
@end
@implementation QNUploadIpGroup
- (instancetype)initWithGroupType:(NSString *)groupType
                           ipList:(NSArray <id <QNIDnsNetworkAddress> > *)ipList{
    if (self = [super init]) {
        _groupType = groupType;
        _ipList = ipList;
    }
    return self;
}
- (id <QNIDnsNetworkAddress>)getServerIP{
    if (!self.ipList || self.ipList.count == 0) {
        return nil;
    } else {
        return self.ipList[arc4random()%self.ipList.count];
    }
}
@end

@interface QNUploadServerDomain: NSObject
@property(atomic   , assign)BOOL isAllFrozen;
@property(nonatomic,   copy)NSString *host;
@property(nonatomic, strong)NSArray <QNUploadIpGroup *> *ipGroupList;
@end
@implementation QNUploadServerDomain
+ (QNUploadServerDomain *)domain:(NSString *)host{
    QNUploadServerDomain *domain = [[QNUploadServerDomain alloc] init];
    domain.host = host;
    domain.isAllFrozen = false;
    return domain;
}
- (QNUploadServer *)getServer{
    if (self.isAllFrozen || !self.host || self.host.length == 0) {
        return nil;
    }
    
    if (!self.ipGroupList || self.ipGroupList.count == 0) {
        [self createIpGroupList];
    }
    
    if (self.ipGroupList && self.ipGroupList.count > 0) {
        QNUploadServer *server = nil;
        for (QNUploadIpGroup *ipGroup in self.ipGroupList) {
            if (![kQNUploadServerFreezeManager isFrozenHost:self.host type:ipGroup.groupType]) {
                id <QNIDnsNetworkAddress> inetAddress = [ipGroup getServerIP];
                server = [QNUploadServer server:self.host host:self.host ip:inetAddress.ipValue source:inetAddress.sourceValue ipPrefetchedTime:inetAddress.timestampValue];
                break;
            }
        }
        if (server == nil) {
            self.isAllFrozen = true;
        }
        return server;
    } else if (![kQNUploadServerFreezeManager isFrozenHost:self.host type:nil]){
        return [QNUploadServer server:self.host host:self.host ip:nil source:nil ipPrefetchedTime:nil];
    } else {
        self.isAllFrozen = true;
        return nil;
    }
}
- (QNUploadServer *)getOneServer{
    if (!self.host || self.host.length == 0) {
        return nil;
    }
    if (self.ipGroupList && self.ipGroupList.count > 0) {
        NSInteger index = arc4random()%self.ipGroupList.count;
        QNUploadIpGroup *ipGroup = self.ipGroupList[index];
        id <QNIDnsNetworkAddress> inetAddress = [ipGroup getServerIP];
        QNUploadServer *server = [QNUploadServer server:self.host host:self.host ip:inetAddress.ipValue source:inetAddress.sourceValue ipPrefetchedTime:inetAddress.timestampValue];;
        return server;
    } else {
        return [QNUploadServer server:self.host host:self.host ip:nil source:nil ipPrefetchedTime:nil];
    }
}
- (void)createIpGroupList{
    @synchronized (self) {
        if (self.ipGroupList && self.ipGroupList.count > 0) {
            return;
        }
        
        NSMutableDictionary *ipGroupInfos = [NSMutableDictionary dictionary];
        NSArray *inetAddresses = [kQNDnsPrefetch getInetAddressByHost:self.host];
        for (id <QNIDnsNetworkAddress> inetAddress in inetAddresses) {
            NSString *ipValue = inetAddress.ipValue;
            NSString *groupType = [QNUtils getIpType:ipValue host:self.host];
            if (groupType) {
                NSMutableArray *ipList = ipGroupInfos[groupType] ?: [NSMutableArray array];
                [ipList addObject:inetAddress];
                ipGroupInfos[groupType] = ipList;
            }
        }
        
        NSMutableArray *ipGroupList = [NSMutableArray array];
        for (NSString *groupType in ipGroupInfos.allKeys) {
            NSArray *ipList = ipGroupInfos[groupType];
            QNUploadIpGroup *ipGroup = [[QNUploadIpGroup alloc] initWithGroupType:groupType ipList:ipList];
            [ipGroupList addObject:ipGroup];
        }
        self.ipGroupList = ipGroupList;
    }
}
- (void)freeze:(NSString *)ip{
    [kQNUploadServerFreezeManager freezeHost:self.host type:[QNUtils getIpType:ip host:self.host]];
}

@end


@interface QNUploadDomainRegion()
// 是否获取过，PS：当第一次获取Domain，而区域所有Domain又全部冻结时，返回一个domain尝试一次
@property(atomic   , assign)BOOL hasGot;
@property(atomic   , assign)BOOL isAllFrozen;
@property(nonatomic, strong)NSArray <NSString *> *domainHostList;
@property(nonatomic, strong)NSDictionary <NSString *, QNUploadServerDomain *> *domainDictionary;
@property(nonatomic, strong)NSArray <NSString *> *oldDomainHostList;
@property(nonatomic, strong)NSDictionary <NSString *, QNUploadServerDomain *> *oldDomainDictionary;

@property(nonatomic, strong, nullable)QNZoneInfo *zoneInfo;
@end
@implementation QNUploadDomainRegion

- (BOOL)isValid{
    return !self.isAllFrozen && (self.domainHostList.count > 0 || self.oldDomainHostList.count > 0);
}

- (void)setupRegionData:(QNZoneInfo *)zoneInfo{
    _zoneInfo = zoneInfo;
    
    self.isAllFrozen = NO;
    NSMutableArray *serverGroups = [NSMutableArray array];
    NSMutableArray *domainHostList = [NSMutableArray array];
    if (zoneInfo.domains) {
        [serverGroups addObjectsFromArray:zoneInfo.domains];
        [domainHostList addObjectsFromArray:zoneInfo.domains];
    }
    self.domainHostList = domainHostList;
    self.domainDictionary = [self createDomainDictionary:serverGroups];
    
    [serverGroups removeAllObjects];
    NSMutableArray *oldDomainHostList = [NSMutableArray array];
    if (zoneInfo.old_domains) {
        [serverGroups addObjectsFromArray:zoneInfo.old_domains];
        [oldDomainHostList addObjectsFromArray:zoneInfo.old_domains];
    }
    self.oldDomainHostList = oldDomainHostList;
    self.oldDomainDictionary = [self createDomainDictionary:serverGroups];
}
- (NSDictionary *)createDomainDictionary:(NSArray <NSString *> *)hosts{
    NSMutableDictionary *domainDictionary = [NSMutableDictionary dictionary];
    
    for (NSString *host in hosts) {
        QNUploadServerDomain *domain = [QNUploadServerDomain domain:host];
        [domainDictionary setObject:domain forKey:host];
    }
    return [domainDictionary copy];
}

- (id<QNUploadServer>)getNextServer:(BOOL)isOldServer
                       freezeServer:(id<QNUploadServer>)freezeServer{
    if (self.isAllFrozen) {
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
    if (server == nil && !self.hasGot && hostList.count > 0) {
        NSInteger index = arc4random()%hostList.count;
        NSString *host = hostList[index];
        server = [domainInfo[host] getOneServer];
    }
    self.hasGot = true;
    if (server == nil) {
        self.isAllFrozen = YES;
    }
    return server;
}
@end
