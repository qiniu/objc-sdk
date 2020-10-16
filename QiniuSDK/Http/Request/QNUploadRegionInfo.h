//
//  QNUploadRegion.h
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNIUploadServer.h"

typedef NS_ENUM(NSInteger, QNServerFrozenLevel){
    QNServerFrozenLevelNone = 1 << 0, // 不冻结
    QNServerFrozenLevelPartFrozen = 1 << 1, // 当前Region冻结，仅影响当前Region
    QNServerFrozenLevelGlobalFrozen = 1 << 2, // 全局冻结
};

NS_ASSUME_NONNULL_BEGIN

@class QNZoneInfo;

@protocol QNUploadRegion <NSObject>

@property(nonatomic, assign, readonly)BOOL isValid;
@property(nonatomic, strong, nullable, readonly)QNZoneInfo *zoneInfo;

- (void)setupRegionData:(QNZoneInfo * _Nullable)zoneInfo;

- (id<QNUploadServer> _Nullable)getNextServer:(BOOL)isOldServer
                                  frozenLevel:(QNServerFrozenLevel)frozenLevel
                                 freezeServer:(id <QNUploadServer> _Nullable)freezeServer;

@end

NS_ASSUME_NONNULL_END
