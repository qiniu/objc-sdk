//
//  QNSystem.h
//  QiniuSDK
//
//  Created by bailong on 15/10/13.
//  Copyright © 2015年 Qiniu. All rights reserved.
//

#ifndef QNSystem_h
#define QNSystem_h

BOOL hasNSURLSession();

BOOL hasAts();

BOOL allowsArbitraryLoads();

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
BOOL isLessIOS9();
#endif

#endif /* QNSystem_h */
