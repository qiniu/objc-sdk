//
//  QNUploader.h
//  QiniuSDK
//
//  Created by bailong on 14-9-28.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AFNetworking/AFNetworking.h>

#import "../Http/QNRequestInfo.h"
#import "../Common/QNConfig.h"
#import "QNUploadManager.h"

@interface QNUploadOption ()
- (NSDictionary *)convertToPostParams;
@end

@implementation QNUploadOption

- (NSMutableDictionary *)convertToPostParams{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:self.params];
    return params;
}

@end

@interface QNUploadManager ()
@property  AFHTTPRequestOperationManager *httpManager;
@property  AFHTTPSessionManager *sesssionManager;
@end



@implementation QNUploadManager

+ (instancetype) create /*(persistent)*/{
    return [[QNUploadManager alloc] init];
}

- (instancetype)init{
    if (self = [super init]) {
        self.httpManager = [[AFHTTPRequestOperationManager alloc] init];
        self.httpManager.responseSerializer = [AFJSONResponseSerializer serializer];
        self.sesssionManager = [[AFHTTPSessionManager alloc] init];
    }
    return self;
}

- (NSError *) putData: (NSData *)data
              withKey:(NSString*)key
            withToken:(NSString*)token
    withCompleteBlock:(QNCompleteBlock)block
           withOption:(QNUploadOption*)option{
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
//    if (key && ![key isEqualToString:kQiniuUndefinedKey]) {
//        parameters[@"key"] = key;
//    }
//    if (!key) {
//        key = kQiniuUndefinedKey;
//    }
    
    parameters[@"token"] = token;
    
    if (option.params) {
        [parameters addEntriesFromDictionary:option.convertToPostParams];
    }
    
    NSString *mimeType = option.mimeType;
    if (!mimeType) {
        mimeType = @"application/octet-stream";
    }
    AFHTTPRequestOperationManager* manager = self.httpManager;
    NSMutableURLRequest *request = [manager.requestSerializer
        multipartFormRequestWithMethod:@"POST"
                            URLString: [NSString stringWithFormat:@"http://%@", kUpHost]
                            parameters:parameters
            constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
    [formData appendPartWithFileData:data
                                name:@"file"
                            fileName:key
                            mimeType:mimeType];}
                                error:nil];
    
    
    AFHTTPRequestOperation *operation = [manager
                HTTPRequestOperationWithRequest:request
                                         success:^(AFHTTPRequestOperation *operation, id responseObject) {block(nil,nil);}
                                         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                             block(nil,nil);}
                                         ];
    
    [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        if (option && option.progress) {
            option.progress((float)totalBytesWritten / (float)totalBytesExpectedToWrite);
        }
    }];
    
    [manager.operationQueue addOperation:operation];
    
    return nil;
}

- (NSError *) putFile: (NSString *)filePath
              withKey:(NSString*)key
            withToken:(NSString*)token
    withCompleteBlock:(QNCompleteBlock)block
           withOption:(QNUploadOption*)option{
    return nil;
}

@end
