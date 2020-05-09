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
- (QNUploadServer *)getNextServer{
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
    if ([self.freezeDate timeIntervalSinceDate:date] < 0){
        return NO;
    } else {
        return YES;
    }
}
- (void)freeze{
    self.freezeDate = [NSDate dateWithTimeIntervalSinceNow:10*60];
}
@end


@interface QNUploadDomainRegion()
@property(atomic   , assign)BOOL isAllFreezed;
@property(nonatomic, strong)NSDictionary <NSString *, QNUploadServerDomain *> *domainDictionary;
@property(nonatomic, strong)NSDictionary <NSString *, QNUploadServerDomain *> *oldDomainDictionary;
@property(nonatomic, strong, nullable)QNZoneInfo *zonesInfo;
@end
@implementation QNUploadDomainRegion

- (void)setupRegionData:(QNZoneInfo *)zoneInfo{
    _zonesInfo = zoneInfo;
    
    self.isAllFreezed = NO;
    NSMutableArray *serverGroups = [NSMutableArray array];
    if (zoneInfo.acc) {
        [serverGroups addObject:zoneInfo.acc];
    }
    if (zoneInfo.src) {
        [serverGroups addObject:zoneInfo.src];
    }
    self.domainDictionary = [self createDomainDictionary:serverGroups];
    
    [serverGroups removeAllObjects];
    if (zoneInfo.old_acc) {
        [serverGroups addObject:zoneInfo.old_acc];
    }
    if (zoneInfo.old_src) {
        [serverGroups addObject:zoneInfo.old_src];
    }
    self.oldDomainDictionary = [self createDomainDictionary:serverGroups];
}
- (NSDictionary *)createDomainDictionary:(NSArray <QNUploadServerGroup *> *)serverGroups{
    NSDate *freezeDate = [NSDate dateWithTimeIntervalSince1970:0];
    NSMutableDictionary *domainDictionary = [NSMutableDictionary dictionary];
    
    for (QNUploadServerGroup *serverGroup in serverGroups) {
        NSMutableArray *hosts = [NSMutableArray array];
        if (serverGroup.main) {
            [hosts addObjectsFromArray:serverGroup.main];
        }
        if (serverGroup.backup) {
            [hosts addObjectsFromArray:serverGroup.backup];
        }
        for (NSString *host in hosts) {
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
    
    NSDictionary *domainInfo = isOldServer ? self.oldDomainDictionary : self.domainDictionary;
    QNUploadServer *server = nil;
    for (QNUploadServerDomain *domainP in domainInfo.allValues) {
        server = [domainP getNextServer];
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
