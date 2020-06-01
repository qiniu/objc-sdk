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

@interface QNUploadServerDomain: NSObject
@property(nonatomic,   copy)NSString *host;
@property(nonatomic, strong)NSArray <NSString *> *ipList;
@property(nonatomic, strong)NSDate *freezeDate;
@end
@implementation QNUploadServerDomain
- (QNUploadServer *)getServer{
    if (!self.host || self.host.length == 0) {
        return nil;
    }
    
    NSDate *currentDate = [NSDate date];
    if ([self isFreezedByDate:currentDate]) {
       return nil;
    }
    
    return [QNUploadServer server:self.host
                             host:self.host
                               ip:self.ipList.firstObject];
}
- (BOOL)isFreezedByDate:(NSDate *)date{
    BOOL isFreezed = YES;
    @synchronized (self) {
        if ([self.freezeDate timeIntervalSinceDate:date] < 0){
            isFreezed = NO;
        }
    }
    return isFreezed;
}
- (void)freeze{
    @synchronized (self) {
        self.freezeDate = [NSDate dateWithTimeIntervalSinceNow:20*60];
    }
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
    self.oldDomainDictionary = [self createDomainDictionary:serverGroups];
}
- (NSDictionary *)createDomainDictionary:(NSArray <QNUploadServerGroup *> *)serverGroups{
    NSDate *freezeDate = [NSDate dateWithTimeIntervalSince1970:0];
    NSMutableDictionary *domainDictionary = [NSMutableDictionary dictionary];
    
    for (QNUploadServerGroup *serverGroup in serverGroups) {
        for (NSString *host in serverGroup.allHosts) {
            QNUploadServerDomain *domain = [[QNUploadServerDomain alloc] init];
            domain.freezeDate = freezeDate;
            domain.host = host;
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
        [_domainDictionary[freezeServer.serverId] freeze];
        [_oldDomainDictionary[freezeServer.serverId] freeze];
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
