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
#import "QNSessionManager.h"
#import "QNUpToken.h"

@interface QNUploadInfoReporter ()
@property (nonatomic, strong) QNReportConfig *config;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) QNSessionManager *sessionManager;
@end

@implementation QNUploadInfoReporter
- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (instancetype)initWithReportConfiguration:(QNReportConfig *)config
{
    self = [super init];
    if (self) {
        _config = config;
        _sessionManager = [[QNSessionManager alloc] initWithProxy:nil timeout:_config.timeoutInterval urlConverter:nil];
    }
    return self;
}

- (void)reportWithResponseInfo:(QNResponseInfo *)info uploadToken:(NSString *)token {
    
    // 检查信息搜集是否开启、文件路径是否存在
    if (!_config.isRecordEnable) return;
    if (!_config.recordDirectory || [_config.recordDirectory isEqualToString:@""]) return;

    // 检查recorder文件是否存在
    if (![_fileManager fileExistsAtPath:_config.recordDirectory]) {
        [_fileManager createFileAtPath:_config.recordDirectory contents:nil attributes:nil];
    }
    
    NSError *error = nil;
    QNFile *file = [[QNFile alloc] init:_config.recordDirectory error:&error];
    if (error) {
        return;
    }
    
    // 判断recorder文件大小是否超过maxRecordFileSize
    if (file.size < _config.maxRecordFileSize) {
        // 上传信息写入recorder文件
        NSString *collectedInfoString = @"200,wxoAAJrJIEQ0M6oU,upload.qiniu.com,115.231.97.46,80,182.0,1499053248,262144,block,262144";
        [collectedInfoString writeToFile:_config.recordDirectory atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            return;
        }
    }
    
    // 判断是否满足上传条件
    NSTimeInterval currentTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
    if ((currentTime - file.modifyTime) > _config.interval * 60 && file.size > _config.uploadThreshold) {
        QNUpToken *parsedToken = [QNUpToken parse:token];
        [_sessionManager post:_config.serverURL withData:[file readAll] withParams:nil withHeaders:nil withCompleteBlock:nil withProgressBlock:nil withCancelBlock:nil withAccess:parsedToken.access];
    }
}

@end
