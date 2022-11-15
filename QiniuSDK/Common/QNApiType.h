//
//  QNApiType.h
//  QiniuSDK
//
//  Created by yangsen on 2022/11/15.
//  Copyright © 2022 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, QNActionType) {
    QNActionTypeNone,
    QNActionTypeUploadByForm,
    QNActionTypeUploadByResumeV1,
    QNActionTypeUploadByResumeV2,
};

@interface QNApiType : NSObject

+ (NSString *)actionTypeString:(QNActionType)actionType;

+ (NSArray <NSString *> *)apisWithActionType:(QNActionType)actionType;

@end

NS_ASSUME_NONNULL_END
