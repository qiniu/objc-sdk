//
//  QNUploadInfoReporter.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNUploadInfoReporter.h"
#import "QNReportConfig.h"
#import "QNResponseInfo.h"
#import "QNFile.h"
#import "QNUpToken.h"
#import "QNUserAgent.h"

static const NSString *recorderFileName = @"recorder";

@interface QNUploadInfoReporter ()
@property (nonatomic, strong) QNReportConfig *config;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *recorderFilePath;
@end

@implementation QNUploadInfoReporter
- (instancetype)initWithReportConfiguration:(QNReportConfig *)config
{
    self = [super init];
    if (self) {
        _config = config;
        _recorderFilePath = [NSString stringWithFormat:@"%@/%@", _config.recordDirectory, recorderFileName];
        _fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (void)clean {
    
    if ([_fileManager fileExistsAtPath:_recorderFilePath]) {
        NSError *error = nil;
        [_fileManager removeItemAtPath:_recorderFilePath error:&error];
        if (error) {
            return;
        }
    }
}

- (void)recordWithUploadResult:(NSString *)result uploadToken:(NSString *)token {
    
    // 检查信息搜集是否开启、文件路径是否存在
    if (!_config.isRecordEnable) return;
    if (!_config.recordDirectory || [_config.recordDirectory isEqualToString:@""]) return;
    if (!result || [result isEqualToString:@""] || !token || [token isEqualToString:@""]) return;

    NSError *error = nil;
    
    // 检查recorder文件是否存在
    if (![_fileManager fileExistsAtPath:_config.recordDirectory]) {
        [_fileManager createDirectoryAtPath:_config.recordDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return;
        }
    }
    
    // 拼接换行符
    NSString *finalRecordInfo = [result stringByAppendingString:@"\n"];
    
    if (![_fileManager fileExistsAtPath:_recorderFilePath]) {
        // 如果recordFile不存在，创建文件并写入首行
        [finalRecordInfo writeToFile:_recorderFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    } else {
        // recordFile存在，拼接文件内容、上传到服务器
        QNFile *file = [[QNFile alloc] init:_recorderFilePath error:&error];
        if (error) {
            return;
        }
        
        // 判断recorder文件大小是否超过maxRecordFileSize
        if (file.size < _config.maxRecordFileSize) {
            // 上传信息写入recorder文件
            NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:_recorderFilePath];
            [fileHandler seekToEndOfFile];
            [fileHandler writeData:[finalRecordInfo dataUsingEncoding:NSUTF8StringEncoding]];
            [fileHandler closeFile];
        }
        
        // 判断是否满足上传条件
        //    NSTimeInterval currentTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
        if (file.size > _config.uploadThreshold) {
            
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_config.serverURL]];
            [request setValue:[NSString stringWithFormat:@"UpToken %@", token] forHTTPHeaderField:@"Authorization"];
            [request setValue:[[QNUserAgent sharedInstance] getUserAgent:[QNUpToken parse:token].access] forHTTPHeaderField:@"User-Agent"];
            [request setHTTPMethod:@"POST"];
            [request setTimeoutInterval:_config.timeoutInterval];
            __block NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:_recorderFilePath] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == 200) {
                    [self clean];
                } else {
                    NSLog(@"upload info report failed");
                }
                [session finishTasksAndInvalidate];
            }];
            [uploadTask resume];
        }
    }
    
    
}

@end
