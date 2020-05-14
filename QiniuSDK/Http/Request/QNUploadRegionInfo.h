//
//  QNUploadRegion.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class QNZoneInfo;
@protocol QNUploadServer <NSObject>

@property(nonatomic,  copy, nullable, readonly)NSString *serverId;
@property(nonatomic,  copy, nullable, readonly)NSString *ip;
@property(nonatomic,  copy, nullable, readonly)NSString *host;

@end


@protocol QNUploadRegion <NSObject>

@property(nonatomic, strong, nullable, readonly)QNZoneInfo *zoneInfo;

- (void)setupRegionData:(QNZoneInfo * _Nullable)zoneInfo;

- (id<QNUploadServer> _Nullable)getNextServer:(BOOL)isOldServer
                                 freezeServer:(id <QNUploadServer> _Nullable)freezeServer;

@end

NS_ASSUME_NONNULL_END
