//
//  QNDefine.h
//  QiniuSDK
//
//  Created by yangsen on 2020/9/4.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kQNWeakSelf __weak typeof(self) weak_self = self
#define kQNStrongSelf __strong typeof(self) self = weak_self

#define kQNWeakObj(object) __weak typeof(object) weak_##object = object
#define kQNStrongObj(object) __strong typeof(object) object = weak_##object
