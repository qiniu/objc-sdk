//
//  QNUploadServerDomainResolver.m
//  AppTest
//
//  Created by yangsen on 2020/4/23.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNUploadRequestState.h"
#import "QNUploadDomainRegion.h"
#import "QNResponseInfo.h"
#import "QNUploadServer.h"
#import "QNZoneInfo.h"
#import "QNUploadServerFreezeUtil.h"
#import "QNUploadServerFreezeManager.h"
#import "QNDnsPrefetch.h"
#import "QNLogUtil.h"
#import "QNUtils.h"
#import "QNDefine.h"
#import "QNUploadServerNetworkStatus.h"

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

- (QNUploadServer *)getServerWithCondition:(BOOL(^)(NSString *host, QNUploadServer *server, QNUploadServer *filterServer, BOOL *stop))condition {

    @synchronized (self) {
        if (!self.ipGroupList || self.ipGroupList.count == 0) {
            [self createIpGroupList];
        }
    }
    
    BOOL stop = NO;
    QNUploadServer *server = nil;
    
    // Host解析出IP时:
    if (self.ipGroupList && self.ipGroupList.count > 0) {
        for (QNUploadIpGroup *ipGroup in self.ipGroupList) {
            
            id <QNIDnsNetworkAddress> inetAddress = [ipGroup getServerIP];
            QNUploadServer *filterServer = [QNUploadServer server:self.host
                                                               ip:inetAddress.ipValue
                                                           source:inetAddress.sourceValue
                                                 ipPrefetchedTime:inetAddress.timestampValue];
            if (condition == nil || condition(self.host, server, filterServer, &stop)) {
                server = filterServer;
            }
            
            if (condition == nil || stop) {
                break;
            }
        }
        return server;
    }
    
    // Host未解析出IP时:
    if (condition == nil || condition(self.host, nil, nil, &stop)) {
        // 未解析时，没有可比性，直接返回自身，自身即为最优
        server = [QNUploadServer server:self.host ip:nil source:nil ipPrefetchedTime:nil];
    }
    
    return server;
}

- (QNUploadServer *)getOneServer{
    if (!self.host || self.host.length == 0) {
        return nil;
    }
    if (self.ipGroupList && self.ipGroupList.count > 0) {
        NSInteger index = arc4random()%self.ipGroupList.count;
        QNUploadIpGroup *ipGroup = self.ipGroupList[index];
        id <QNIDnsNetworkAddress> inetAddress = [ipGroup getServerIP];
        QNUploadServer *server = [QNUploadServer server:self.host ip:inetAddress.ipValue source:inetAddress.sourceValue ipPrefetchedTime:inetAddress.timestampValue];;
        return server;
    } else {
        return [QNUploadServer server:self.host ip:nil source:nil ipPrefetchedTime:nil];
    }
}

- (void)createIpGroupList{

    @synchronized (self) {
        if (self.ipGroupList && self.ipGroupList.count > 0) {
            return;
        }
        
        // get address List of host
        NSArray *inetAddresses = [kQNDnsPrefetch getInetAddressByHost:self.host];
        if (!inetAddresses || inetAddresses.count == 0) {
            return;
        }
        
        // address List to ipList of group & check ip network
        NSMutableDictionary *ipGroupInfos = [NSMutableDictionary dictionary];
        for (id <QNIDnsNetworkAddress> inetAddress in inetAddresses) {
            NSString *ipValue = inetAddress.ipValue;
            NSString *groupType = [QNUtils getIpType:ipValue host:self.host];
            if (groupType) {
                NSMutableArray *ipList = ipGroupInfos[groupType] ?: [NSMutableArray array];
                [ipList addObject:inetAddress];
                ipGroupInfos[groupType] = ipList;
            }
        }
        
        // ipList of group to ipGroup List
        NSMutableArray *ipGroupList = [NSMutableArray array];
        for (NSString *groupType in ipGroupInfos.allKeys) {
            NSArray *ipList = ipGroupInfos[groupType];
            QNUploadIpGroup *ipGroup = [[QNUploadIpGroup alloc] initWithGroupType:groupType ipList:ipList];
            [ipGroupList addObject:ipGroup];
        }
        
        self.ipGroupList = ipGroupList;
    }
}

@end


@interface QNUploadDomainRegion()

// 是否支持http3
@property(nonatomic, assign)BOOL isSupportHttp3;

// 是否获取过，PS：当第一次获取Domain，而区域所有Domain又全部冻结时，返回一个domain尝试一次
@property(atomic   , assign)BOOL hasGot;
@property(atomic   , assign)BOOL isAllFrozen;
// 局部http2冻结管理对象
@property(nonatomic, strong)QNUploadServerFreezeManager *partialHttp2Freezer;
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
    
    QNLogInfo(@"region :%@",domainHostList);
    QNLogInfo(@"region old:%@",oldDomainHostList);
}

- (NSDictionary *)createDomainDictionary:(NSArray <NSString *> *)hosts{
    NSMutableDictionary *domainDictionary = [NSMutableDictionary dictionary];
    
    for (NSString *host in hosts) {
        QNUploadServerDomain *domain = [QNUploadServerDomain domain:host];
        [domainDictionary setObject:domain forKey:host];
    }
    return [domainDictionary copy];
}

- (id<QNUploadServer> _Nullable)getNextServer:(QNUploadRequestState *)requestState
                                 responseInfo:(QNResponseInfo *)responseInfo
                                 freezeServer:(id <QNUploadServer> _Nullable)freezeServer{
    if (self.isAllFrozen) {
        return nil;
    }
    
    [self freezeServerIfNeed:responseInfo freezeServer:freezeServer];
    
    QNUploadServer *server = nil;
    NSArray *hostList = requestState.isUseOldServer ? self.oldDomainHostList : self.domainHostList;
    NSDictionary *domainInfo = requestState.isUseOldServer ? self.oldDomainDictionary : self.domainDictionary;
    
    // 1. 优先使用http3
    if (self.isSupportHttp3 && [requestState.httpVersion isEqualToString:kQNHttpVersion3]) {
        for (NSString *host in hostList) {
            server = [domainInfo[host] getServerWithCondition:^BOOL(NSString *host, QNUploadServer *serverP, QNUploadServer *filterServer, BOOL *stop) {
                
                // 1.1 剔除冻结对象
                NSString *frozenType = QNUploadFrozenType(host, filterServer.ip);
                BOOL isFrozen = [QNUploadServerFreezeUtil isType:frozenType
                                          frozenByFreezeManagers:@[kQNUploadGlobalHttp3Freezer]];
                if (isFrozen) {
                    return NO;
                }
                
                // 1.2 挑选网络状态最优
                return [QNUploadServerNetworkStatus isServerNetworkBetter:filterServer thanServerB:serverP];
            }];
        }
        
        if (server) {
            server.httpVersion = kQNHttpVersion3;
            return server;
        }
    }
    
    
    // 2. 挑选http2
    for (NSString *host in hostList) {
        kQNWeakSelf;
        server = [domainInfo[host] getServerWithCondition:^BOOL(NSString *host, QNUploadServer *serverP, QNUploadServer *filterServer, BOOL *stop) {
            kQNStrongSelf;
            
            // 2.1 剔除冻结对象
            NSString *type = [QNUtils getIpType:filterServer.ip host:host];
            BOOL isFrozen = [QNUploadServerFreezeUtil isType:type
                                      frozenByFreezeManagers:@[self.partialHttp2Freezer, kQNUploadGlobalHttp2Freezer]];
            if (isFrozen) {
                return NO;
            }
            
            // 2.2 挑选网络状态最优
            return [QNUploadServerNetworkStatus isServerNetworkBetter:filterServer thanServerB:serverP];
        }];
    }

    // 3. 无可用 server 随机获取一个
    if (server == nil && !self.hasGot && hostList.count > 0) {
        NSInteger index = arc4random()%hostList.count;
        NSString *host = hostList[index];
        server = [domainInfo[host] getOneServer];
        [self unfreezeServer:server];
    }
    
    self.hasGot = true;
    if (server == nil) {
        self.isAllFrozen = YES;
    }
    
    server.httpVersion = kQNHttpVersion2;
    
    QNLogInfo(@"get server host:%@ ip:%@", server.host, server.ip);
    return server;
}

- (void)freezeServerIfNeed:(QNResponseInfo *)responseInfo
              freezeServer:(QNUploadServer *)freezeServer {
    
    if (freezeServer == nil || freezeServer.serverId == nil || responseInfo == nil) {
        return;
    }
    
    NSString *frozenType = QNUploadFrozenType(freezeServer.host, freezeServer.ip);
    if ([freezeServer.httpVersion isEqualToString:kQNHttpVersion3]) {
        [kQNUploadGlobalHttp3Freezer freezeType:frozenType frozenTime:kQNUploadHttp3FrozenTime];
        return;
    }
    
    // 无法连接到Host || Host不可用， 局部冻结
    if (!responseInfo.canConnectToHost || responseInfo.isHostUnavailable) {
        QNLogInfo(@"partial freeze server host:%@ ip:%@", freezeServer.host, freezeServer.ip);
        
        [self.partialHttp2Freezer freezeType:frozenType frozenTime:kQNGlobalConfiguration.partialHostFrozenTime];
    }
    
    // Host不可用，全局冻结
    if (responseInfo.isHostUnavailable) {
        QNLogInfo(@"global freeze server host:%@ ip:%@", freezeServer.host, freezeServer.ip);
        
        [kQNUploadGlobalHttp2Freezer freezeType:frozenType frozenTime:kQNGlobalConfiguration.globalHostFrozenTime];
    }
}

/// 仅仅解封局部的
- (void)unfreezeServer:(QNUploadServer *)freezeServer {
    if (freezeServer == nil) {
        return;
    }

    NSString *frozenType = QNUploadFrozenType(freezeServer.host, freezeServer.ip);
    [self.partialHttp2Freezer unfreezeType:frozenType];
}

- (QNUploadServerFreezeManager *)partialHttp2Freezer{
    if (!_partialHttp2Freezer) {
        _partialHttp2Freezer = [[QNUploadServerFreezeManager alloc] init];
    }
    return _partialHttp2Freezer;
}

@end
