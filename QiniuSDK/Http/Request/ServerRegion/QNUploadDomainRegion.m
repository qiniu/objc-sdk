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

@interface QNUploadIpGroup : NSObject
@property(nonatomic,   copy, readonly)NSString *groupType;
@property(nonatomic, strong, readonly)NSArray <NSString *> *ipList;
@end
@implementation QNUploadIpGroup
- (instancetype)initWithGroupType:(NSString *)groupType
                           ipList:(NSArray <NSString *> *)ipList{
    if (self = [super init]) {
        _groupType = groupType;
        _ipList = ipList;
    }
    return self;
}
- (NSString *)getServerIP{
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
                server = [QNUploadServer server:self.host host:self.host ip:[ipGroup getServerIP]];
                break;
            }
        }
        if (server == nil) {
            self.isAllFrozen = true;
        }
        return server;
    } else if (![kQNUploadServerFreezeManager isFrozenHost:self.host type:nil]){
        return [QNUploadServer server:self.host host:self.host ip:nil];
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
        QNUploadServer *server = [QNUploadServer server:self.host host:self.host ip:[ipGroup getServerIP]];;
        return server;
    } else {
        return [QNUploadServer server:self.host host:self.host ip:nil];
    }
}
- (void)createIpGroupList{
    @synchronized (self) {
        if (self.ipGroupList && self.ipGroupList.count > 0) {
            return;
        }
        
        NSMutableDictionary *ipGroupInfos = [NSMutableDictionary dictionary];
        NSArray *inetAddresses = [kQNDnsPrefetch getInetAddressByHost:self.host];
        for (id <QNInetAddressDelegate> inetAddress in inetAddresses) {
            NSString *ipValue = inetAddress.ipValue;
            NSString *groupType = [self getIpType:ipValue];
            if (groupType) {
                NSMutableArray *ipList = ipGroupInfos[groupType] ?: [NSMutableArray array];
                [ipList addObject:ipValue];
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
    [kQNUploadServerFreezeManager freezeHost:self.host type:[self getIpType:ip]];
}
- (NSString *)getIpType:(NSString *)ip{
    
    NSString *type = nil;
    if (!ip || ip.length == 0) {
        return type;
    }
    if ([ip containsString:@":"]) {
        type = [self getIPV6StringType:ip];
    } else if ([ip containsString:@"."]){
        type = [self getIPV4StringType:ip];
    }
    return type;
}

- (NSString *)getIPV4StringType:(NSString *)ipv4String{
    NSString *type = nil;
    NSArray *ipNumberStrings = [ipv4String componentsSeparatedByString:@"."];
    if (ipNumberStrings.count == 4) {
        NSInteger firstNumber = [ipNumberStrings.firstObject integerValue];
        if (firstNumber > 0 && firstNumber < 127) {
            type = [NSString stringWithFormat:@"%@-%ld", @"ipv4-A", firstNumber];
        } else if (firstNumber > 127 && firstNumber <= 191) {
            NSInteger secondNumber = [ipNumberStrings[1] integerValue];
            type = [NSString stringWithFormat:@"%@-%ld-%ld", @"ipv4-B", firstNumber, secondNumber];
        } else if (firstNumber > 191 && firstNumber <= 223) {
            NSInteger secondNumber = [ipNumberStrings[1] integerValue];
            NSInteger thirdNumber = [ipNumberStrings[2] integerValue];
            type = [NSString stringWithFormat:@"%@-%ld-%ld-%ld", @"ipv4-C", firstNumber, secondNumber, thirdNumber];
        }
    }
    return type;
}

- (NSString *)getIPV6StringType:(NSString *)ipv6String{
    NSArray *ipNumberStrings = [ipv6String componentsSeparatedByString:@":"];
    NSMutableArray *ipNumberStringsReal = [@[@"0000", @"0000", @"0000", @"0000",
                                            @"0000", @"0000", @"0000", @"0000"] mutableCopy];
    NSArray *suppleStrings = @[@"0000", @"000", @"00", @"0", @""];
    NSInteger i = 0;
    while (i < ipNumberStrings.count) {
        NSString *ipNumberString = ipNumberStrings[i];
        if (ipNumberString.length > 0) {
            ipNumberString = [NSString stringWithFormat:@"%@%@", suppleStrings[ipNumberString.length], ipNumberString];
            ipNumberStringsReal[i] = ipNumberString;
        } else {
            break;
        }
        i++;
    }
    
    NSInteger j = ipNumberStrings.count - 1;
    NSInteger indexReal = ipNumberStringsReal.count - 1;
    while (i < j) {
        NSString *ipNumberString = ipNumberStrings[j];
        if (ipNumberString.length > 0) {
            ipNumberString = [NSString stringWithFormat:@"%@%@", suppleStrings[ipNumberString.length], ipNumberString];
            ipNumberStringsReal[indexReal] = ipNumberString;
        } else {
            break;
        }
        j--;
        indexReal--;
    }
    return [[ipNumberStringsReal subarrayWithRange:NSMakeRange(0, 4)] componentsJoinedByString:@"-"];
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

- (void)setupRegionData:(QNZoneInfo *)zoneInfo{
    _zoneInfo = zoneInfo;
    
    self.isAllFrozen = NO;
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
