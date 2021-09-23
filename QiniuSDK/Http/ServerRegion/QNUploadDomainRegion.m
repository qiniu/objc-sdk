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
@property(nonatomic, assign)int ipIndex;
@property(nonatomic,   copy, readonly)NSString *groupType;
@property(nonatomic, strong, readonly)NSArray <id <QNIDnsNetworkAddress> > *ipList;
@end
@implementation QNUploadIpGroup
- (instancetype)initWithGroupType:(NSString *)groupType
                           ipList:(NSArray <id <QNIDnsNetworkAddress> > *)ipList{
    if (self = [super init]) {
        _groupType = groupType;
        _ipList = ipList;
        _ipIndex = -1;
    }
    return self;
}
- (id <QNIDnsNetworkAddress>)getServerIP{
    if (!self.ipList || self.ipList.count == 0) {
        return nil;
    } else {
        if (_ipIndex < 0 || _ipIndex > (self.ipList.count - 1)) {
            _ipIndex = arc4random()%self.ipList.count;
        }
        return self.ipList[_ipIndex];
    }
}
@end

@interface QNUploadServerDomain: NSObject
@property(nonatomic,   copy)NSString *host;
@property(nonatomic, strong)NSArray <QNUploadIpGroup *> *ipGroupList;
@end
@implementation QNUploadServerDomain

+ (QNUploadServerDomain *)domain:(NSString *)host{
    QNUploadServerDomain *domain = [[QNUploadServerDomain alloc] init];
    domain.host = host;
    return domain;
}

- (QNUploadServer *)getServerWithCondition:(BOOL(^)(NSString *host, QNUploadServer *server, QNUploadServer *filterServer))condition {

    @synchronized (self) {
        if (!self.ipGroupList || self.ipGroupList.count == 0) {
            [self createIpGroupList];
        }
    }
    
    QNUploadServer *server = nil;
    
    // Host解析出IP时:
    if (self.ipGroupList && self.ipGroupList.count > 0) {
        for (QNUploadIpGroup *ipGroup in self.ipGroupList) {
            
            id <QNIDnsNetworkAddress> inetAddress = [ipGroup getServerIP];
            QNUploadServer *filterServer = [QNUploadServer server:self.host
                                                               ip:inetAddress.ipValue
                                                           source:inetAddress.sourceValue
                                                 ipPrefetchedTime:inetAddress.timestampValue];
            if (condition == nil || condition(self.host, server, filterServer)) {
                server = filterServer;
            }
            
            if (condition == nil) {
                break;
            }
        }
        return server;
    }
    
    // Host未解析出IP时:
    if (condition == nil || condition(self.host, nil, nil)) {
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

- (void)clearIpGroupList {
    @synchronized (self) {
        self.ipGroupList = nil;
    }
}

- (void)createIpGroupList {

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
@property(nonatomic, assign)BOOL http3Enabled;

// 是否冻结过Host，PS：如果没有冻结过 Host,则当前 Region 上传也就不会有错误信息，可能会返回-9，所以必须要再进行一次尝试
@property(atomic   , assign)BOOL hasFreezeHost;
@property(atomic   , assign)BOOL isAllFrozen;
// 局部http2冻结管理对象
@property(nonatomic, strong)QNUploadServerFreezeManager *partialHttp2Freezer;
@property(nonatomic, strong)QNUploadServerFreezeManager *partialHttp3Freezer;
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
    self.hasFreezeHost = NO;
    self.http3Enabled = zoneInfo.http3Enabled;
    // 暂时屏蔽
    self.http3Enabled = false;
    
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

- (void)updateIpListFormHost:(NSString *)host {
    if (host == nil) {
        return;
    }
    
    [self.domainDictionary[host] clearIpGroupList];
    [self.oldDomainDictionary[host] clearIpGroupList];
}

- (id<QNUploadServer> _Nullable)getNextServer:(QNUploadRequestState *)requestState
                                 responseInfo:(QNResponseInfo *)responseInfo
                                 freezeServer:(id <QNUploadServer> _Nullable)freezeServer{
    if (self.isAllFrozen) {
        return nil;
    }
    
    [self freezeServerIfNeed:responseInfo freezeServer:freezeServer];
    
    QNUploadServer *server = nil;
    BOOL isUseOldServer = requestState.isUseOldServer;
    NSArray *hostList = isUseOldServer ? self.oldDomainHostList : self.domainHostList;
    NSDictionary *domainInfo = isUseOldServer ? self.oldDomainDictionary : self.domainDictionary;
    
    // 1. 优先使用http3
    if (self.http3Enabled) {
        for (NSString *host in hostList) {
            QNUploadServer *domainServer = [domainInfo[host] getServerWithCondition:^BOOL(NSString *host, QNUploadServer *serverP, QNUploadServer *filterServer) {
                
                // 1.1 剔除冻结对象
                NSString *frozenType = QNUploadFrozenType(host, filterServer.ip);
                BOOL isFrozen = [QNUploadServerFreezeUtil isType:frozenType
                                          frozenByFreezeManagers:@[self.partialHttp2Freezer, kQNUploadGlobalHttp3Freezer]];
                if (isFrozen) {
                    return NO;
                }
                
                // 1.2 挑选网络状态最优
                return [QNUploadServerNetworkStatus isServerNetworkBetter:filterServer thanServerB:serverP];
            }];
            server = [QNUploadServerNetworkStatus getBetterNetworkServer:server serverB:domainServer];
            
            if (server) {
                break;
            }
        }
        
        if (server) {
            server.httpVersion = kQNHttpVersion3;
            return server;
        }
    }
    
    
    // 2. 挑选http2
    for (NSString *host in hostList) {
        kQNWeakSelf;
        QNUploadServer *domainServer = [domainInfo[host] getServerWithCondition:^BOOL(NSString *host, QNUploadServer *serverP, QNUploadServer *filterServer) {
            kQNStrongSelf;
            
            // 2.1 剔除冻结对象
            NSString *frozenType = QNUploadFrozenType(host, filterServer.ip);
            BOOL isFrozen = [QNUploadServerFreezeUtil isType:frozenType
                                      frozenByFreezeManagers:@[self.partialHttp2Freezer, kQNUploadGlobalHttp2Freezer]];
            if (isFrozen) {
                return NO;
            }
            
            // 2.2 挑选网络状态最优
            return [QNUploadServerNetworkStatus isServerNetworkBetter:filterServer thanServerB:serverP];
        }];
        server = [QNUploadServerNetworkStatus getBetterNetworkServer:server serverB:domainServer];
        
        if (server) {
            break;
        }
    }

    // 3. 无可用 server 且未冻结过 Host 则随机获取一个
    if (server == nil && !self.hasFreezeHost && hostList.count > 0) {
        NSInteger index = arc4random()%hostList.count;
        NSString *host = hostList[index];
        server = [domainInfo[host] getOneServer];
        [self unfreezeServer:server];
    }
    
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
    // 1. http3 冻结
    if (kQNIsHttp3(freezeServer.httpVersion)) {
        if (responseInfo.isNotQiniu) {
            self.hasFreezeHost = YES;
            [self.partialHttp3Freezer freezeType:frozenType frozenTime:kQNGlobalConfiguration.partialHostFrozenTime];
        }
        
        if (!responseInfo.canConnectToHost || responseInfo.isHostUnavailable) {
            self.hasFreezeHost = YES;
            [kQNUploadGlobalHttp3Freezer freezeType:frozenType frozenTime:kQNUploadHttp3FrozenTime];
        }
        return;
    }
    
    // 2. http2 冻结
    // 2.1 无法连接到Host || Host不可用， 局部冻结
    if (responseInfo.isNotQiniu || !responseInfo.canConnectToHost || responseInfo.isHostUnavailable) {
        QNLogInfo(@"partial freeze server host:%@ ip:%@", freezeServer.host, freezeServer.ip);
        self.hasFreezeHost = YES;
        [self.partialHttp2Freezer freezeType:frozenType frozenTime:kQNGlobalConfiguration.partialHostFrozenTime];
    }
    
    // 2.2 Host不可用，全局冻结
    if (responseInfo.isHostUnavailable) {
        QNLogInfo(@"global freeze server host:%@ ip:%@", freezeServer.host, freezeServer.ip);
        self.hasFreezeHost = YES;
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

- (QNUploadServerFreezeManager *)partialHttp3Freezer{
    if (!_partialHttp3Freezer) {
        _partialHttp3Freezer = [[QNUploadServerFreezeManager alloc] init];
    }
    return _partialHttp3Freezer;
}

@end
