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
#import "QNSystemTool.h"
#import "QNVersion.h"
#import <objc/runtime.h>

// Upload Result Type
NSString *const upload_ok = @"ok";
NSString *const zero_size_file = @"zero_size_file";
NSString *const invalid_file = @"invalid_file";
NSString *const invalid_args = @"invalid_args";

// Network Error Type
NSString *const unknown_error = @"unknown_error";
NSString *const network_error = @"network_error";
NSString *const timeout = @"timeout";
NSString *const unknown_host = @"unknown_host";
NSString *const cannot_connect_to_host = @"cannot_connect_to_host";
NSString *const transmission_error = @"transmission_error";
NSString *const proxy_error = @"proxy_error";
NSString *const ssl_error = @"ssl_error";
NSString *const response_error = @"response_error";
NSString *const parse_error = @"parse_error";
NSString *const malicious_response = @"malicious_response";
NSString *const user_canceled = @"user_canceled";
NSString *const bad_request = @"bad_request";

@interface QNReportBaseItem ()
// 打点类型 request、block、quality
@property (nonatomic, copy) NSString *log_type;
// 客户端时间戳
@property (nonatomic, assign) uint64_t up_time;
@end

@implementation QNReportBaseItem
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.up_time = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
    }
    return self;
}
- (NSString *)toJson {
    NSMutableDictionary *requestItemDic = [NSMutableDictionary dictionary];
    
    // self class property
    unsigned int selfPropertyCount = 0;
    objc_property_t *selfProperties = class_copyPropertyList([self class], &selfPropertyCount);
    for (unsigned int i = 0; i < selfPropertyCount; i ++) {
        objc_property_t property = selfProperties[i];
        const char *name = property_getName(property);
        unsigned int attrCount = 0;
        objc_property_attribute_t * attrs = property_copyAttributeList(property, &attrCount);
        for (unsigned int j = 0; j < attrCount; j ++) {
            objc_property_attribute_t attr = attrs[j];
            const char *attrName = attr.name;
            if (0 == strcmp(attrName, "T")) {
                const char *value = attr.value;
                if (0 == strcmp(value, "@\"NSString\"")) {
                    NSString *key = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
                    if ([key isEqualToString:@"log_type"]) {
                        NSLog(@"lalala");
                    }
                    NSString *ivarValue = [self valueForKey:key];
                    if (ivarValue) [requestItemDic setValue:ivarValue forKey:key];
                } else {
                    // 默认其他属性的基本类型是int
                    NSString *key = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
                    NSNumber *ivarValue = [self valueForKey:key];
                    if (ivarValue) [requestItemDic setValue:ivarValue forKey:key];
                }
            }
        }
        free(attrs);
    }
    free(selfProperties);
    
    // super class property
    unsigned int superPropertyCount = 0;
    objc_property_t *superProperties = class_copyPropertyList([self superclass], &superPropertyCount);
    for (unsigned int i = 0; i < superPropertyCount; i ++) {
        objc_property_t property = superProperties[i];
        const char *name = property_getName(property);
        unsigned int attrCount = 0;
        objc_property_attribute_t * attrs = property_copyAttributeList(property, &attrCount);
        for (unsigned int j = 0; j < attrCount; j ++) {
            objc_property_attribute_t attr = attrs[j];
            const char *attrName = attr.name;
            if (0 == strcmp(attrName, "T")) {
                const char *value = attr.value;
                if (0 == strcmp(value, "@\"NSString\"")) {
                    NSString *key = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
                    if ([key isEqualToString:@"log_type"]) {
                        NSLog(@"lalala");
                    }
                    NSString *ivarValue = [self valueForKey:key];
                    if (ivarValue) [requestItemDic setValue:ivarValue forKey:key];
                } else {
                    // 默认其他属性的基本类型是int
                    NSString *key = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
                    NSNumber *ivarValue = [self valueForKey:key];
                    if (ivarValue) [requestItemDic setValue:ivarValue forKey:key];
                }
            }
        }
        free(attrs);
    }
    free(superProperties);
        
    NSError *error;
    NSData *requestItemData = [NSJSONSerialization dataWithJSONObject:requestItemDic options:NSJSONWritingPrettyPrinted error:&error];
    if (error) return nil;
    NSString *requestItemJson = [[NSString alloc] initWithData:requestItemData encoding:NSUTF8StringEncoding];
    return requestItemJson;
}
@end

@interface QNReportRequestItem ()
// API 请求类型，可选值有 "form"，"mkblk"，"bput"，"mkfile"，"put"，"init_parts"，"upload_part"，"complete_part"，"uc_query"，"httpdns_query"
@property (nonatomic, copy) NSString *up_type;

// 记录⽬标 Bucket 名称
@property (nonatomic, copy) NSString *target_bucket;
// 记录⽬标 Key 名称
@property (nonatomic, copy) NSString *target_key;
// 本次分片上传的偏移量，单位为字节
@property (nonatomic, assign) uint64_t file_offset;
// ⽬标上传的区域 ID，可选值为 "z0"，"z1"，"z2"，"as0"，"na0" 等
@property (nonatomic, copy) NSString *target_region_id;
// 当前上传的区域 ID，可选值为 "z0"，"z1"，"z2"，"as0"，"na0" 等
@property (nonatomic, copy) NSString *current_region_id;
// 该域名通过预取 DNS 得到的 IP 地址数量（目前是0）
@property (nonatomic, assign) int64_t prefetched_ip_count;

// 当前进程 ID
@property (nonatomic, assign) int64_t pid;
// 当前线程 ID
@property (nonatomic, assign) int64_t tid;

// 当前平台的操作系统名称
@property (nonatomic, copy) NSString *os_name;
// 当前平台的操作系统版本号
@property (nonatomic, copy) NSString *os_version;
// 当前 SDK 名称，默认Object-C
@property (nonatomic, copy) NSString *sdk_name;
// 当前 SDK 版本号
@property (nonatomic, copy) NSString *sdk_version;

// 记录响应状态码
@property (nonatomic, assign) int16_t status_code;
// 记录响应中存储的 ReqId
@property (nonatomic, copy) NSString *req_id;
// 记录主机域名(不含解析，不含端⼝)
@property (nonatomic, copy) NSString *host;
// 记录成功建⽴连接的服务器 IP 地址
@property (nonatomic, copy) NSString *remote_ip;
// 记录主机端口号
@property (nonatomic, assign) uint16_t port;
// 记录从发送请求到收到响应之间的单调时间差，单位为毫秒
@property (nonatomic, assign) uint64_t total_elapsed_time;
// 记录⼀次请求中 DNS 查询的耗时，单位为毫秒，如果当前请求不需要进⾏ DNS 查询，则填写 0
@property (nonatomic, assign) uint64_t dns_elapsed_time;
// 记录一次请求中建立⽹络连接的耗时，单位为毫秒，如果当前请求不不需要进行⽹络连接，则填写 0
@property (nonatomic, assign) uint64_t connect_elapsed_time;
// 记录一次请求中建立安全⽹络连接的耗时，单位为毫秒(该耗时被 connect_elapsed_time 包含，因此总是⼩小于或等于 connect_elapsed_time，如果当前请求不需要进行安全连接，则填写 0)
@property (nonatomic, assign) uint64_t tls_connect_elapsed_time;
// 记录⼀次请求中发送请求的耗时，单位为毫秒
@property (nonatomic, assign) uint64_t request_elapsed_time;
// 记录⼀次请求中从发送请求完毕到收到响应前的耗时，单位为毫秒
@property (nonatomic, assign) uint64_t wait_elapsed_time;
// 记录⼀次请求中读取响应的耗时，单位为毫秒
@property (nonatomic, assign) uint64_t response_elapsed_time;
// 本次成功发送请求的请求体大小，单位为字节
@property (nonatomic, assign) uint64_t bytes_sent;
// 预期发送请求的请求体大小，单位为字节
@property (nonatomic, assign) uint64_t bytes_total;

// 错误类型
@property (nonatomic, copy) NSString *error_type;
// 对于服务器器成功响应，且响应体中包含 error 字段的，则给出 error 字段的内容。否则对于其他错误，则可以⾃自定义错误描述 信息
@property (nonatomic, copy) NSString *error_description;


// 请求结束时的⽹网络类型，可选值有 "wifi", "2g", "3g", "4g" 等。如果当前⽹网络不不可⽤用，则给出 "none"
@property (nonatomic, copy) NSString *network_type;
// 请求结束时的信号强度
@property (nonatomic, assign) int64_t signal_strength;
@end

@implementation QNReportRequestItem
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.log_type = @"request";
    }
    return self;
}

+ (instancetype)buildWithUpType:(NSString *)up_type
                   TargetBucket:(NSString *)target_bucket
                            targetKey:(NSString *)target_key
                           fileOffset:(uint64_t)file_offset
                       targetRegionId:(NSString *)target_region_id
                      currentRegionId:(NSString *)current_region_id
                    prefetchedIpCount:(int64_t)prefetched_ip_count
                                  pid:(int64_t)pid
                                  tid:(int64_t)tid
                           statusCode:(int16_t)status_code
                                reqId:(NSString *)req_id
                                 host:(NSString *)host
                             remoteIp:(NSString *)remote_ip
                                 port:(uint16_t)port
                     totalElapsedTime:(uint64_t)total_elapsed_time
                       dnsElapsedTime:(uint64_t)dns_elapsed_time
                   connectElapsedTime:(uint64_t)connect_elapsed_time
                tlsConnectElapsedTime:(uint64_t)tls_connect_elapsed_time
                   requestElapsedTime:(uint64_t)request_elapsed_time
                      waitElapsedTime:(uint64_t)wait_elapsed_time
                  responseElapsedTime:(uint64_t)response_elapsed_time
                            bytesSent:(uint64_t)bytes_sent
                           bytesTotal:(uint64_t)bytes_total
                            errorType:(NSString *)error_type
                     errorDescription:(NSString *)error_description
                          networkType:(NSString *)network_type
                      signalStrength:(int64_t)signal_strength {
    
    QNReportRequestItem *item = [[QNReportRequestItem alloc] init];
    item.up_type = up_type;
    item.target_bucket = target_bucket;
    item.target_key = target_key;
    item.file_offset = file_offset;
    item.target_region_id = target_region_id;
    item.current_region_id = current_region_id;
    item.prefetched_ip_count = prefetched_ip_count;
    item.pid = pid;
    item.tid = tid;
    item.status_code = status_code;
    item.req_id = req_id;
    item.host = host;
    item.remote_ip = remote_ip;
    item.port = port;
    item.total_elapsed_time = total_elapsed_time;
    item.dns_elapsed_time = dns_elapsed_time;
    item.connect_elapsed_time = connect_elapsed_time;
    item.tls_connect_elapsed_time = tls_connect_elapsed_time;
    item.request_elapsed_time = request_elapsed_time;
    item.wait_elapsed_time = wait_elapsed_time;
    item.response_elapsed_time = response_elapsed_time;
    item.bytes_sent = bytes_sent;
    item.bytes_total = bytes_total;
    item.error_type = error_type;
    item.error_description = error_description;
    item.network_type = network_type;
    item.signal_strength = signal_strength;
    
    item.os_name = [[UIDevice currentDevice] model];
    item.os_version = [[UIDevice currentDevice] systemVersion];
    item.sdk_name = @"Object-C";
    item.sdk_version = kQiniuVersion;

    return item;
}

@end

// block type item - 用于统计分片上传整体质量信息
@interface QNReportBlockItem ()

// ⽬标上传的区域 ID，可选值为 "z0"，"z1"，"z2"，"as0"，"na0"
@property (nonatomic, copy) NSString *target_region_id;
// 当前上传的区域 ID，可选值为 "z0"，"z1"，"z2"，"as0"，"na0"
@property (nonatomic, copy) NSString *current_region_id;
// 记录对于当前上传的区域，从发送第一个请求到收到最后一个响应 之间的单调时间差，单位为毫秒
@property (nonatomic, assign) uint64_t total_elapsed_time;
// 成功上传⾄服务器的分块尺寸总和，单位为字节
@property (nonatomic, assign) uint64_t bytes_sent;
// 上次失败时已上传的文件尺⼨(也就是上传恢复点)，单位为字节
@property (nonatomic, assign) uint64_t recovered_from;
// 要上传的文件总尺寸，单位为字节
@property (nonatomic, assign) uint64_t file_size;
// 当前进程 ID
@property (nonatomic, assign) int64_t pid;
// 当前线程 ID
@property (nonatomic, assign) int64_t tid;
// 分⽚上传 API 版本，可选值为 1 和 2
@property (nonatomic, assign) uint8_t up_api_version;

@end

@implementation QNReportBlockItem
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.log_type = @"block";
    }
    return self;
}

+ (instancetype)buildWithTargetRegionId:(NSString *)target_region_id
                        currentRegionId:(NSString *)current_region_id
                       totalElapsedTime:(uint64_t)total_elapsed_time
                              bytesSent:(uint64_t)bytes_sent
                          recoveredFrom:(uint64_t)recovered_from
                               fileSize:(uint64_t)file_size
                                    pid:(int64_t)pid
                                    tid:(int64_t)tid
                           upApiVersion:(uint8_t)up_api_version {
    
    QNReportBlockItem *item = [[QNReportBlockItem alloc] init];
    item.target_region_id = target_region_id;
    item.current_region_id = current_region_id;
    item.total_elapsed_time = total_elapsed_time;
    item.bytes_sent = bytes_sent;
    item.recovered_from = recovered_from;
    item.file_size = file_size;
    item.pid = pid;
    item.tid = tid;
    item.up_api_version = up_api_version;
        
    return item;
}
@end

// quality type item - 用于统计上传结果
@interface QNReportQualityItem ()

// 记录上传结果
@property (nonatomic, copy) NSString *result;
// 记录对于当前上传的⽂文件，从发送第⼀个请求到收到最后⼀个响应之间的单调时间差，单位为毫秒
@property (nonatomic, assign) uint64_t total_elapsed_time;
// 为了完成本次上传所发出的 HTTP 请求总数(含 UC Query 和 HTTPDNS Query)
@property (nonatomic, assign) uint64_t requests_count;
// 为了完成本次上传所使用的区域数量
@property (nonatomic, assign) uint64_t regions_count;
// 为了完成本次上传所发出的 HTTP 请求体尺寸总量(含 UC Query 和 HTTPDNS Query)
@property (nonatomic, assign) uint64_t bytes_sent;
// 公有云 "public", 私有云"private"
@property (nonatomic, copy) NSString *cloud_type;

@end

@implementation QNReportQualityItem
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.log_type = @"quality";
    }
    return self;
}

+ (instancetype)buildWithResult:(NSString *)result
               totalElapsedTime:(uint64_t)total_elapsed_time
                  requestsCount:(uint64_t)requests_count
                   regionsCount:(uint64_t)regions_count
                      bytesSent:(uint64_t)bytes_sent
                      cloudType:(NSString *)cloud_type {
    
    QNReportQualityItem *item = [[QNReportQualityItem alloc] init];
    item.result = result;
    item.total_elapsed_time = total_elapsed_time;
    item.requests_count = requests_count;
    item.regions_count = regions_count;
    item.bytes_sent = bytes_sent;
    item.cloud_type = cloud_type;
    
    return item;
}

@end

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
        _reportEnable = YES;
        _interval = 10;
        _serverURL = @"https://uplog.qbox.me/log/4";
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
@property (nonatomic, copy) NSString *X_Log_Client_Id;

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
        _recordQueue = dispatch_queue_create("com.qiniu.reporter", DISPATCH_QUEUE_SERIAL);
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
    
    if (!_config.isReportEnable) return NO;
    if (!(_config.maxRecordFileSize > _config.uploadThreshold)) {
        QNAsyncRunInMain(^{
            NSLog(@"maxRecordFileSize must be larger than uploadThreshold");
        });
        return NO;
    }
    return YES;
}

- (void)report:(NSString *)jsonString token:(NSString *)token {
    
    if (![self checkReportAvailable] || !jsonString) return;
    
    // 串行队列处理文件读写
    dispatch_async(_recordQueue, ^{
        [self innerReport:jsonString token:token];
    });
}

- (void)innerReport:(NSString *)jsonString token:(NSString *)token {
    
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
    NSString *finalRecordInfo = [jsonString stringByAppendingString:@"\n"];
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
            if (self.X_Log_Client_Id) {
                [request setValue:self.X_Log_Client_Id forHTTPHeaderField:@"X-Log-Client-Id"];
            }
            [request setHTTPMethod:@"POST"];
            [request setTimeoutInterval:_config.timeoutInterval];
            __block NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:_recorderFilePath] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == 200) {
                    self.lastReportTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
                    NSDictionary *respHeader = httpResponse.allHeaderFields;
                    if (!self.X_Log_Client_Id && [respHeader.allKeys containsObject:@"X-Log-Client-Id"]) {
                        self.X_Log_Client_Id = respHeader[@"X-Log-Client-Id"];
                    }
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
