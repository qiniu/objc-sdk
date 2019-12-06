//
//  QNUploadInfoReporter.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNUploadInfoReporter.h"
#import "QNResponseInfo.h"
#import "QNFile.h"
#import "QNUpToken.h"
#import "QNUserAgent.h"
#import "QNAsyncRun.h"

@implementation QNReportConfig

+ (instancetype)sharedInstance {
    
    static QNReportConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordEnable = YES;
        _interval = 10;
        _serverURL = @"https://uplog.qbox.me/log/3";
        _recordDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.qiniu.report"];
        _maxRecordFileSize = 2 * 1024 * 1024;
        _uploadThreshold = 4 * 1024;
        _timeoutInterval = 10;
    }
    return self;
}

@end

static const NSString *recorderFileName = @"recorder";
static const NSString *reportTypeValueList[] = {@"form", @"mkblk", @"bput", @"mkfile", @"block"};

@interface QNUploadInfoReporter ()

@property (nonatomic, strong) QNReportConfig *config;
@property (nonatomic, assign) NSTimeInterval lastReportTime;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *recorderFilePath;
@property (nonatomic, strong) dispatch_queue_t recordQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end

@implementation QNUploadInfoReporter

+ (instancetype)sharedInstance {
    
    static QNUploadInfoReporter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _config = [QNReportConfig sharedInstance];
        _lastReportTime = 0;
        _recorderFilePath = [NSString stringWithFormat:@"%@/%@", _config.recordDirectory, recorderFileName];
        _fileManager = [NSFileManager defaultManager];
        _recordQueue = dispatch_queue_create("com.qiniu.report", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)clean {
    
    if ([_fileManager fileExistsAtPath:_recorderFilePath]) {
        NSError *error = nil;
        [_fileManager removeItemAtPath:_recorderFilePath error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                NSLog(@"remove recorder file failed: %@", error);
            });
            return;
        }
    }
}

- (BOOL)checkReportAvailable {
    
    if (!_config.isRecordEnable) return NO;
    if (!(_config.maxRecordFileSize > _config.uploadThreshold)) {
        QNAsyncRunInMain(^{
            NSLog(@"maxRecordFileSize must be larger than uploadThreshold");
        });
        return NO;
    }
    return YES;
}

- (void)recordWithRequestType:(QNReportType)requestType
                                responseInfo:(QNResponseInfo *)responseInfo
                                   bytesSent:(UInt32)bytesSent
                                    fileSize:(UInt32)fileSize
                                    token:(NSString *)token {
    
    if (![self checkReportAvailable]) return;
    
    NSString *nullString = @"";
    NSArray *reportItems = @[
                              [NSString stringWithFormat:@"%d", responseInfo.statusCode] ? [NSString stringWithFormat:@"%d", responseInfo.statusCode] : nullString,
                              responseInfo.reqId ? responseInfo.reqId : nullString,
                              responseInfo.host ? responseInfo.host : nullString,
                              responseInfo.serverIp ? responseInfo.serverIp : nullString,
                              nullString,
                              [NSString stringWithFormat:@"%.1f", responseInfo.duration * 1000] ? [NSString stringWithFormat:@"%.1f", responseInfo.duration * 1000] : nullString,
                              [NSString stringWithFormat:@"%llu", responseInfo.timeStamp] ? [NSString stringWithFormat:@"%llu", responseInfo.timeStamp] : nullString,
                              [NSString stringWithFormat:@"%u", (unsigned int)bytesSent] ? [NSString stringWithFormat:@"%u", (unsigned int)bytesSent] : nullString,
                              reportTypeValueList[requestType],
                              [NSString stringWithFormat:@"%u", (unsigned int)fileSize] ? [NSString stringWithFormat:@"%u", (unsigned int)fileSize] : nullString
                              ];
    
    // 串行队列处理文件读写
    dispatch_async(_recordQueue, ^{
        [self innerRecordWithUploadResult:[reportItems componentsJoinedByString:@","] uploadToken:token];
    });
}

- (void)innerRecordWithUploadResult:(NSString *)result uploadToken:(NSString *)token {
    
    // 检查recorder文件夹是否存在
    NSError *error = nil;
    if (![_fileManager fileExistsAtPath:_config.recordDirectory]) {
        [_fileManager createDirectoryAtPath:_config.recordDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                NSLog(@"create record directory failed, please check record directory: %@", error.localizedDescription);
            });
            return;
        }
    }

    // 拼接换行符
    NSString *finalRecordInfo = [result stringByAppendingString:@"\n"];
    if (![_fileManager fileExistsAtPath:_recorderFilePath]) {
        // 如果recordFile不存在，创建文件并写入首行，首次不上传
        [finalRecordInfo writeToFile:_recorderFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    } else {
        // recordFile存在，拼接文件内容、上传到服务器
        QNFile *file = [[QNFile alloc] init:_recorderFilePath error:&error];
        if (error) {
            QNAsyncRunInMain(^{
                NSLog(@"create QNFile with path failed: %@", error.localizedDescription);
            });
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
        
        // 判断是否满足上传条件：文件大于上报临界值 && (首次上传 || 距上次上传时间大于_config.interval)
        NSTimeInterval currentTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
        if (file.size > _config.uploadThreshold && (_lastReportTime == 0 || currentTime - _lastReportTime > _config.interval * 60)) {
            
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_config.serverURL]];
            [request setValue:[NSString stringWithFormat:@"UpToken %@", token] forHTTPHeaderField:@"Authorization"];
            [request setValue:[[QNUserAgent sharedInstance] getUserAgent:[QNUpToken parse:token].access] forHTTPHeaderField:@"User-Agent"];
            [request setHTTPMethod:@"POST"];
            [request setTimeoutInterval:_config.timeoutInterval];
            __block NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:_recorderFilePath] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == 200) {
                    self.lastReportTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
                    [self clean];
                } else {
                    QNAsyncRunInMain(^{
                        NSLog(@"upload info report failed: %@", error.localizedDescription);
                    });
                }
                [session finishTasksAndInvalidate];
                dispatch_semaphore_signal(self.semaphore);
            }];
            [uploadTask resume];
            
            // 控制上传过程中，文件内容不被修改
            _semaphore = dispatch_semaphore_create(0);
            dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        }
    }
}

@end
