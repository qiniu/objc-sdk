//
//  QNLogUtil.h
//  QiniuSDK
//
//  Created by yangsen on 2020/12/25.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QNLogLevel){
    QNLogLevelNone,
    QNLogLevelError,
    QNLogLevelWarn,
    QNLogLevelInfo,
    QNLogLevelDebug,
    QNLogLevelVerbose
};

@interface QNLogUtil : NSObject

+ (void)setLogLevel:(QNLogLevel)level;

+ (void)log:(QNLogLevel)level
       file:(NSString *)file
   function:(NSString *)function
       line:(NSUInteger)line
     format:(NSString *)format, ...;


@end

#define QNLog(level, format) [QNLogUtil log:level file:__File__ function:__func__ line:__LINE__ format:format]

#define QNLogError(format)   QNLog(QNLogLevelError, format)
#define QNLogWarn(format)    QNLog(QNLogLevelWarn, format)
#define QNLogInfo(format)    QNLog(QNLogLevelInfo, format)
#define QNLogDebug(format)   QNLog(QNLogLevelDebug, format)
#define QNLogVerbose(format) QNLog(QNLogLevelVerbose, format)

NS_ASSUME_NONNULL_END
