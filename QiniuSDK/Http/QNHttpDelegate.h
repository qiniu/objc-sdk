#import <Foundation/Foundation.h>

@class QNResponseInfo;

typedef void (^QNInternalProgressBlock)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef void (^QNCompleteBlock)(QNResponseInfo *info, NSDictionary *resp);
typedef BOOL (^QNCancelBlock)(void);

typedef NS_ENUM(NSUInteger, QNUploadRequestType) {
    RequestType_mkblk,
    RequestType_bput,
    RequestType_mkfile,
    RequestType_form,
};

/**
 *    Http 客户端接口
 */
@protocol QNHttpDelegate <NSObject>

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
   withTaskIdentifier:(NSString *)taskIdentifier
    withCompleteBlock:(QNCompleteBlock)completeBlock
    withProgressBlock:(QNInternalProgressBlock)progressBlock
      withCancelBlock:(QNCancelBlock)cancelBlock
           withAccess:(NSString *)access;

- (void)post:(NSString *)url
    withData:(NSData *)data
  withParams:(NSDictionary *)params
 withHeaders:(NSDictionary *)headers
withTaskIdentifier:(NSString *)taskIdentifier
withCompleteBlock:(QNCompleteBlock)completeBlock
withProgressBlock:(QNInternalProgressBlock)progressBlock
withCancelBlock:(QNCancelBlock)cancelBlock
  withAccess:(NSString *)access;

- (void)invalidateSessionWithIdentifier:(NSString *)identifier;

@end
