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

+ (void)enableLogDate:(BOOL)enable;
+ (void)enableLogFile:(BOOL)enable;
+ (void)enableLogFunction:(BOOL)enable;

+ (void)log:(QNLogLevel)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString * _Nullable)format, ...;


@end

#define QNLog(level, fmt, ...) \
    [QNLogUtil log:level \
              file:__FILE__ \
          function:__FUNCTION__  \
              line:__LINE__ \
              format:(fmt), ##__VA_ARGS__]

#define QNLogError(format, ...)   QNLog(QNLogLevelError, format, ##__VA_ARGS__)
#define QNLogWarn(format, ...)    QNLog(QNLogLevelWarn, format, ##__VA_ARGS__)
#define QNLogInfo(format, ...)    QNLog(QNLogLevelInfo, format, ##__VA_ARGS__)
#define QNLogDebug(format, ...)   QNLog(QNLogLevelDebug, format, ##__VA_ARGS__)
#define QNLogVerbose(format, ...) QNLog(QNLogLevelVerbose, format, ##__VA_ARGS__)

NS_ASSUME_NONNULL_END
