//
//  QNUploadServer.h
//  AppTest
//
//  Created by yangsen on 2020/4/23.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNUploadRegionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface QNUploadServer : NSObject <QNUploadServer>

+ (instancetype)server:(NSString * _Nullable)serverId
                  host:(NSString * _Nullable)host
                    ip:(NSString * _Nullable)ip;

@end

NS_ASSUME_NONNULL_END
