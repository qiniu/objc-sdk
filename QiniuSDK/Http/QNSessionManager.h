

#import <Foundation/Foundation.h>
#import "QNConfiguration.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)

@class QNHttpResponseInfo;

typedef void (^QNInternalProgressBlock)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef void (^QNCompleteBlock)(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody);
typedef BOOL (^QNCancelBlock)(void);

@interface QNSessionStatistics : NSObject

@property (nonatomic, copy) NSString *remoteIp;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) uint64_t totalElapsedTime;
@property (nonatomic, assign) uint64_t dnsElapsedTime;
@property (nonatomic, assign) uint64_t connectElapsedTime;
@property (nonatomic, assign) uint64_t tlsConnectElapsedTime;
@property (nonatomic, assign) uint64_t requestElapsedTime;
@property (nonatomic, assign) uint64_t waitElapsedTime;
@property (nonatomic, assign) uint64_t responseElapsedTime;
@property (nonatomic, assign) uint64_t bytesSent;
@property (nonatomic, assign) uint64_t bytesTotal;
@property (nonatomic, assign, getter=isProxyConnection) BOOL proxyConnection;

@end

@interface QNSessionManager : NSObject

- (instancetype)initWithProxy:(NSDictionary *)proxyDict
                      timeout:(UInt32)timeout
                 urlConverter:(QNUrlConvert)converter;

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
   withIdentifier:(NSString *)identifier
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock
           withAccess:(NSString *)access;

- (void)post:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
          withHeaders:(NSDictionary *)headers
    withIdentifier:(NSString *)identifier
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock
           withAccess:(NSString *)access;

- (void)get:(NSString *)url
          withHeaders:(NSDictionary *)headers
    withCompleteBlock:(QNCompleteBlock)completeBlock;

- (void)invalidateSessionWithIdentifier:(NSString *)identifier;

@end

#endif
