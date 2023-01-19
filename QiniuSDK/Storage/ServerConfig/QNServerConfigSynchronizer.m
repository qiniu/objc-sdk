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
#import <pthread.h>

static NSString *Token = nil;
static NSArray <NSString *> *Hosts = nil;
static pthread_mutex_t TokenMutexLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t HostsMutexLock = PTHREAD_MUTEX_INITIALIZER;

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
        // 上传时才会有 token，不上传不请求，避免不必要请求
        if (serverConfigTransaction != nil) {
            return nil;
        }
        
        QNUpToken *token = [QNUpToken parse:self.token];
        if (token == nil) {
            token = [QNUpToken getInvalidToken];
        }
        
        NSArray *hosts = self.hosts;
        if (hosts == nil) {
            hosts = kQNPreQueryHosts;
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
        
        QNUpToken *token = [QNUpToken parse:self.token];
        if (token == nil || !token.isValid) {
            return nil;
        }
        
        NSArray *hosts = self.hosts;
        if (hosts == nil) {
            hosts = kQNPreQueryHosts;
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
    pthread_mutex_lock(&TokenMutexLock);
    Token = token;
    pthread_mutex_unlock(&TokenMutexLock);
}

+ (NSString *)token {
    NSString *token = nil;
    pthread_mutex_lock(&TokenMutexLock);
    token = Token;
    pthread_mutex_unlock(&TokenMutexLock);
    return token;
}

+ (void)setHosts:(NSArray<NSString *> *)servers {
    pthread_mutex_lock(&HostsMutexLock);
    Hosts = [servers copy];
    pthread_mutex_unlock(&HostsMutexLock);
}

+ (NSArray<NSString *> *)hosts {
    NSArray<NSString *> *hosts = nil;
    pthread_mutex_lock(&HostsMutexLock);
    hosts = [Hosts copy];
    pthread_mutex_unlock(&HostsMutexLock);
    return hosts;
}

@end
