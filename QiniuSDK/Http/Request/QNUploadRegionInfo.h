//
//  QNUploadRegion.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNIUploadServer.h"

NS_ASSUME_NONNULL_BEGIN

@class QNZoneInfo;

@protocol QNUploadRegion <NSObject>

@property(nonatomic, assign, readonly)BOOL isValid;
@property(nonatomic, strong, nullable, readonly)QNZoneInfo *zoneInfo;

- (void)setupRegionData:(QNZoneInfo * _Nullable)zoneInfo;

- (id<QNUploadServer> _Nullable)getNextServer:(BOOL)isOldServer
                                 freezeServer:(id <QNUploadServer> _Nullable)freezeServer;

@end

NS_ASSUME_NONNULL_END
