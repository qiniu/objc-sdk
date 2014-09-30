//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Common/QNTask.h"
#import "QNUploader.h"

@interface QNUploadOption ()
- (NSDictionary *)convertToPostParams;
@end

@implementation QNUploadOption

- (NSMutableDictionary *)convertToPostParams{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.params];
    return params;
}

@end


@implementation QNUploader

+ (instancetype) create /*(persistent)*/{
    return [[QNUploader alloc] init];
}


- (QNTask *) putData: (NSData *)data
             withKey:(NSString*)key
           withToken:(NSString*)token
          withOption:(QNUploadOption*)option {
    return nil;
}

- (QNTask *) putFile: (NSString *)filePath
             withKey:(NSString*)key
           withToken:(NSString*)token
          withOption:(QNUploadOption*)option {
    return nil;
}
@end
