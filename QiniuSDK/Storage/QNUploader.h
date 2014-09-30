//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^QNProgressBlock)(float percent);
typedef BOOL (^QNCancelBlock)(void);

@class QNTask;

@interface QNUploadOption : NSObject

@property (copy, nonatomic) NSDictionary* params;
@property (copy, nonatomic) NSString* mimeType;
@property BOOL checkCrc;
@property (copy) QNProgressBlock progress;
@property (copy) QNCancelBlock cancelToken;

@end

@interface QNUploader : NSObject

+ (instancetype) create /*(persistent)*/;

- (QNTask *) putData: (NSData *)data
             withKey:(NSString*)key
           withToken:(NSString*)token
          withOption:(QNUploadOption*)option;

- (QNTask *) putFile: (NSString *)filePath
             withKey:(NSString*)key
           withToken:(NSString*)token
          withOption:(QNUploadOption*)option;

//- (QNTask *) putRecord;
@end

