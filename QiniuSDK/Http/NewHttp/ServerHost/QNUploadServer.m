//
//  QNUploadServer.m
//  AppTest
//
//  Created by yangsen on 2020/4/23.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNUploadServer.h"

@interface QNUploadServer()

@property(nonatomic,  copy)NSString *serverId;
@property(nonatomic,  copy)NSString *ip;
@property(nonatomic,  copy)NSString *host;

@end
@implementation QNUploadServer

+ (instancetype)server:(NSString *)serverId
                  host:(NSString *)host
                    ip:(NSString *)ip{
    QNUploadServer *server = [[QNUploadServer alloc] init];
    server.serverId = serverId;
    server.ip = ip;
    server.host = host;
    return server;
}

@end
