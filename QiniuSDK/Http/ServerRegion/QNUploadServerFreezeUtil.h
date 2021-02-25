//
//  QNUploadServerFreezeUtil.h
//  QiniuSDK
//
//  Created by yangsen on 2021/2/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNUploadServerFreezeManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define kQNUploadHttp3FrozenTime (3600 * 24)
#define QNUploadFrozenType(HOST, IP) ([QNUploadServerFreezeUtil getFrozenType:HOST ip:IP])

#define kQNUploadGlobalHttp3Freezer [QNUploadServerFreezeUtil sharedHttp3Freezer]
#define kQNUploadGlobalHttp2Freezer [QNUploadServerFreezeUtil sharedHttp2Freezer]

@interface QNUploadServerFreezeUtil : NSObject

+ (QNUploadServerFreezeManager *)sharedHttp2Freezer;
+ (QNUploadServerFreezeManager *)sharedHttp3Freezer;

+ (BOOL)isType:(NSString *)type frozenByFreezeManagers:(NSArray <QNUploadServerFreezeManager *> *)freezeManagerList;

+ (NSString *)getFrozenType:(NSString *)host ip:(NSString *)ip;

@end

NS_ASSUME_NONNULL_END
