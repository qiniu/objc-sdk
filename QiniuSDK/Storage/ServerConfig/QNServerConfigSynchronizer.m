//
//  QNServerConfigSynchronizer.m
//  QiniuSDK
//
//  Created by yangsen on 2021/8/30.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNConfig.h"
#import "QNUpToken.h"
#import "QNZoneInfo.h"
#import "QNResponseInfo.h"
#import "QNRequestTransaction.h"
#import "QNServerConfigSynchronizer.h"


static NSString *Token = nil;
static NSArray <NSString *> *Hosts = nil;
static QNRequestTransaction *serverConfigTransaction = nil;
static QNRequestTransaction *serverUserConfigTransaction = nil;

@implementation QNServerConfigSynchronizer

//MARK: --- server config
+ (void)getServerConfigFromServer:(void(^)(QNServerConfig *config))complete {
    if (complete == nil) {
        return;
    }
    
    QNRequestTransaction *transaction = [self createServerConfigTransaction];
    if (transaction == nil) {
        complete(nil);
        return;
    }
    
    [transaction serverConfig:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        if (responseInfo.isOK && response != nil) {
            complete([QNServerConfig config:response]);
        } else {
            complete(nil);
        }
        [self destroyServerConfigRequestTransaction];
    }];
}

+ (QNRequestTransaction *)createServerConfigTransaction {
    @synchronized (self) {
        if (serverConfigTransaction != nil) {
            return nil;
        }
        
        QNUpToken *token = [QNUpToken parse:Token];
        if (token == nil) {
            token = [QNUpToken getInvalidToken];
        }
        
        NSArray *hosts = Hosts;
        if (hosts == nil) {
            hosts = @[kQNPreQueryHost00, kQNPreQueryHost01];
        }
        QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:hosts
                                                                               regionId:QNZoneInfoEmptyRegionId
                                                                                  token:token];
        serverConfigTransaction = transaction;
        return transaction;
    }
}

+ (void)destroyServerConfigRequestTransaction {
    @synchronized (self) {
        serverConfigTransaction = nil;
    }
}

//MARK: --- server user config
+ (void)getServerUserConfigFromServer:(void(^)(QNServerUserConfig *config))complete {
    if (complete == nil) {
        return;
    }
    
    QNRequestTransaction *transaction = [self createServerUserConfigTransaction];
    if (transaction == nil) {
        complete(nil);
        return;
    }
    
    [transaction serverUserConfig:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        if (responseInfo.isOK && response != nil) {
            complete([QNServerUserConfig config:response]);
        } else {
            complete(nil);
        }
        [self destroyServerConfigRequestTransaction];
    }];
}

+ (QNRequestTransaction *)createServerUserConfigTransaction {
    @synchronized (self) {
        if (serverConfigTransaction != nil) {
            return nil;
        }
        
        QNUpToken *token = [QNUpToken parse:Token];
        if (token == nil || !token.isValid) {
            return nil;
        }
        
        NSArray *hosts = Hosts;
        if (hosts == nil) {
            hosts = @[kQNPreQueryHost00, kQNPreQueryHost01];
        }
        QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithHosts:hosts
                                                                               regionId:QNZoneInfoEmptyRegionId
                                                                                  token:token];
        serverUserConfigTransaction = transaction;
        return transaction;
    }
}

+ (void)destroyServerUserConfigRequestTransaction {
    @synchronized (self) {
        serverUserConfigTransaction = nil;
    }
}

+ (void)setToken:(NSString *)token {
    Token = token;
}

+ (NSString *)token {
    return Token;
}

+ (void)setHosts:(NSArray<NSString *> *)servers {
    Hosts = [servers copy];
}

+ (NSArray<NSString *> *)hosts {
    return Hosts;
}

@end
