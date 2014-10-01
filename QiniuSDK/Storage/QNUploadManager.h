//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QNRequestInfo;
typedef void (^QNProgressBlock)(float percent);
typedef void (^QNCompleteBlock)(QNRequestInfo* info, NSDictionary* resp);
typedef BOOL (^QNCancelBlock)(void);

@class QNTask;

@interface QNUploadOption : NSObject

@property (copy, nonatomic) NSDictionary* params;
@property (copy, nonatomic) NSString* mimeType;
@property BOOL checkCrc;
@property (copy) QNProgressBlock progress;
@property (copy) QNCancelBlock cancelToken;

@end

@interface QNUploadManager : NSObject

+ (instancetype) create /*(persistent)*/;

- (NSError *) putData: (NSData *)data
             withKey:(NSString*)key
           withToken:(NSString*)token
    withCompleteBlock:(QNCompleteBlock)block
           withOption:(QNUploadOption*)option;

- (NSError *) putFile: (NSString *)filePath
             withKey:(NSString*)key
           withToken:(NSString*)token
    withCompleteBlock:(QNCompleteBlock)block
          withOption:(QNUploadOption*)option;

//- (QNTask *) putRecord;
@end

