//
//  QNConcurrentResumeUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/7/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNConcurrentResumeUpload.h"

@interface QNConcurrentRecorderInfo : NSObject

@property (nonatomic, strong) NSNumber *totalSize;     // total size of the file
@property (nonatomic, strong) NSNumber *modifyTime;  // modify time of the file
@property (nonatomic, copy) NSString *host;          // upload host used last time
@property (nonatomic, strong) NSArray<NSDictionary *> *contextsInfo;  // concurrent upload contexts info

- (instancetype)init __attribute__((unavailable("use recorderInfoWithTotalSize:totalSize:modifyTime:host:contextsInfo: instead.")));

@end

@implementation QNConcurrentRecorderInfo

+ (instancetype)recorderInfoWithTotalSize:(NSNumber *)totalSize modifyTime:(NSNumber *)modifyTime host:(NSString *)host contextsInfo:(NSArray<NSDictionary *> *)contextsInfo {
    return [[QNConcurrentRecorderInfo alloc] initWithTotalSize:totalSize modifyTime:modifyTime host:host contextsInfo:contextsInfo];
}

- (instancetype)initWithTotalSize:(NSNumber *)totalSize modifyTime:(NSNumber *)modifyTime host:(NSString *)host contextsInfo:(NSArray<NSDictionary *> *)contextsInfo {
    
    self = [super init];
    if (self) {
        _totalSize = totalSize ? totalSize : @0;
        _modifyTime = modifyTime ? modifyTime : @0;
        _host = host ? host : @"";
        _contextsInfo = contextsInfo ? contextsInfo : @[];
    }
    return self;
}

- (NSData *)buildRecorderInfoJsonData:(NSError **)error {
    
    NSDictionary *recorderInfo = @{
        @"total_size": _totalSize,
        @"modify_time": _modifyTime,
        @"host": _host,
        @"contexts_info": _contextsInfo
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:recorderInfo options:NSJSONWritingPrettyPrinted error:error];
    return data;
}

+ (QNConcurrentRecorderInfo *)buildRecorderInfoWithData:(NSData *)data error:(NSError **)error {
    
    NSDictionary *recorderInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:error];
    return [[self class] recorderInfoWithTotalSize:recorderInfo[@"total_size"] modifyTime:recorderInfo[@"modify_time"] host:recorderInfo[@"host"] contextsInfo:recorderInfo[@"contexts_info"]];
}

@end

@interface QNConcurrentTask: NSObject

@property (nonatomic, assign) int index; // block index in the file
@property (nonatomic, assign) UInt32 size; // total size of the block
@property (atomic, assign) UInt32 uploadedSize; // uploaded size of the block
@property (nonatomic, copy) NSString *context;
@property (nonatomic, assign) BOOL isTaskCompleted;

- (instancetype)init __attribute__((unavailable("use concurrentTaskWithBlockIndex:blockSize: instead.")));

@end

@implementation QNConcurrentTask

+ (instancetype)concurrentTaskWithBlockIndex:(int)index blockSize:(UInt32)size {
    return [[QNConcurrentTask alloc] initWithBlockIndex:index blockSize:size];
}

- (instancetype)initWithBlockIndex:(int)index blockSize:(UInt32)size
{
    self = [super init];
    if (self) {
        _isTaskCompleted = NO;
        _uploadedSize = 0;
        _size = size;
        _index = index;
    }
    return self;
}

@end

@interface QNConcurrentTaskQueue: NSObject

@property (nonatomic, strong) id<QNFileDelegate> file;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) QNUpToken *token; // token
@property (nonatomic, assign) UInt32 totalSize; // 文件总大小
@property (nonatomic, strong) QNConcurrentRecorderInfo *recordInfo; // 续传信息

@property (nonatomic, copy) NSString *upHost; // 并行队列当前使用的上传域名
@property (nonatomic, assign) UInt32 retriedTimes; // 当前域名重试次数
@property (nonatomic, assign) QNZoneInfoType currentZoneType;

@property (nonatomic, strong) NSMutableArray<QNConcurrentTask *> *taskQueueArray; // block 任务队列
@property (nonatomic, assign) UInt32 taskQueueCount; // 实际并发任务数量
@property (atomic, assign) int nextTaskIndex; // 下一个任务的index
@property (nonatomic, assign, getter=isAllCompleted) BOOL isAllCompleted; // completed
@property (nonatomic, assign, getter=totalPercent) float totalPercent; // 上传总进度

@property (nonatomic, assign) BOOL isConcurrentTaskError; // error
@property (nonatomic, strong) QNResponseInfo *info; // errorInfo if error
@property (nonatomic, strong) NSDictionary *resp; // errorResp if error

- (instancetype)init __attribute__((unavailable("use taskQueueWithFile:config:totalSize:recordInfo:token: instead.")));

@end

@implementation QNConcurrentTaskQueue

+ (instancetype)taskQueueWithFile:(id<QNFileDelegate>)file
                           config:(QNConfiguration *)config
                        totalSize:(UInt32)totalSize
                       recordInfo:(QNConcurrentRecorderInfo *)recordInfo
                            token:(QNUpToken *)token {
    
    return [[QNConcurrentTaskQueue alloc] initWithFile:file
                                                config:config
                                             totalSize:totalSize
                                            recordInfo:recordInfo
                                                 token:token];
}

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                      config:(QNConfiguration *)config
                   totalSize:(UInt32)totalSize
                  recordInfo:(QNConcurrentRecorderInfo *)recordInfo
                       token:(QNUpToken *)token {
    
    self = [super init];
    if (self) {
        _file = file;
        _config = config;
        _totalSize = totalSize;
        _recordInfo = recordInfo;
        _token = token;
        
        _retriedTimes = 0;
        _currentZoneType = QNZoneInfoTypeMain;
        
        _taskQueueArray = [NSMutableArray array];
        _isConcurrentTaskError = NO;
        _nextTaskIndex = 0;
        _taskQueueCount = 0;
                
        _upHost = [self getNextHostWithCurrentZoneType:_currentZoneType frozenDomain:nil];
        [self initTaskQueue];
    }
    return self;
}

- (void)initTaskQueue {
    
    // add recover task
    if (_recordInfo.contextsInfo.count > 0) {
        for (NSDictionary *info in _recordInfo.contextsInfo) {
            int block_index = [info[@"block_index"] intValue];
            UInt32 block_size = [info[@"block_size"] unsignedIntValue];
            NSString *context = info[@"context"];
            QNConcurrentTask *recoveryTask = [QNConcurrentTask concurrentTaskWithBlockIndex:block_index blockSize:block_size];
            recoveryTask.uploadedSize = block_size;
            recoveryTask.context = context;
            recoveryTask.isTaskCompleted = YES;
            [_taskQueueArray addObject:recoveryTask];
        }
    }
    
    int blockCount = _totalSize % kQNBlockSize == 0 ? _totalSize / kQNBlockSize : _totalSize / kQNBlockSize + 1;
    _taskQueueCount = blockCount > _config.concurrentTaskCount ? _config.concurrentTaskCount : blockCount;
    
    for (int i = 0; i < blockCount; i++) {
        BOOL isTaskExisted = NO;
        for (int j = 0; j < _taskQueueArray.count; j++) {
            if (_taskQueueArray[j].index == i) {
                isTaskExisted = YES;
                break;
            }
        }
        if (!isTaskExisted) {
            UInt32 left = _totalSize - i * kQNBlockSize;
            UInt32 blockSize = left < kQNBlockSize ? left : kQNBlockSize;
            QNConcurrentTask *task = [QNConcurrentTask concurrentTaskWithBlockIndex:i blockSize:blockSize];
            [_taskQueueArray addObject:task];
        }
    }
}

- (QNConcurrentTask *)getNextTask {
    
    QNConcurrentTask *nextTask = nil;
    while (_nextTaskIndex < _taskQueueArray.count) {
        QNConcurrentTask *task = _taskQueueArray[_nextTaskIndex];
        _nextTaskIndex++;
        if (!task.isTaskCompleted) {
            nextTask = task;
            break;
        }
    }
    return nextTask;
}

- (BOOL)switchNextHost {
    
    _retriedTimes = 0;
    _upHost = [self getNextHostWithCurrentZoneType:_currentZoneType frozenDomain:_upHost];
    return _upHost != nil;
}

- (BOOL)switchZoneWithType:(QNZoneInfoType)zoneType {
    
    QNZonesInfo *zonesInfo = [_config.zone getZonesInfoWithToken:_token];
    if (zoneType == QNZoneInfoTypeBackup && (_currentZoneType == QNZoneInfoTypeBackup || !zonesInfo.hasBackupZone)) {
        return NO;
    }

    // reset
    _recordInfo = nil;
    _resp = nil;
    _info = nil;
    _retriedTimes = 0;
    _nextTaskIndex = 0;
    _taskQueueCount = 0;
    _isConcurrentTaskError = NO;
    _currentZoneType = zoneType;
    _upHost = [self getNextHostWithCurrentZoneType:zoneType frozenDomain:nil];
    [_taskQueueArray removeAllObjects];
    
    [self initTaskQueue];
    return YES;
}

- (void)buildErrorWithInfo:(QNResponseInfo *)info resp:(NSDictionary *)resp {
    
    if (_isConcurrentTaskError) return;
    _isConcurrentTaskError = YES;
    _info = info;
    _resp = resp;
}

- (BOOL)completeTask:(QNConcurrentTask *)task withContext:(NSString *)context {
    
    task.uploadedSize = task.size;
    task.context = context;
    task.isTaskCompleted = YES;
    
    return _nextTaskIndex < _taskQueueArray.count;
}

- (NSString *)getNextHostWithCurrentZoneType:(QNZoneInfoType)currentZoneType frozenDomain:(NSString *)frozenDomain {
    
    // use recordInfo.host first, then get host in normal
    NSString *nextUpHost = nil;
    if (_recordInfo.host && ![_recordInfo.host isEqualToString:@""]) {
        nextUpHost = _recordInfo.host;
    } else {
        nextUpHost = [self.config.zone up:self.token zoneInfoType:currentZoneType isHttps:self.config.useHttps frozenDomain:frozenDomain];
    }
    _upHost = nextUpHost ? nextUpHost : _upHost;
    return nextUpHost;
}

- (NSArray *)getRecordInfo {
    
    NSMutableArray *infoArray = [NSMutableArray array];
    for (QNConcurrentTask *task in _taskQueueArray) {
        if (task.isTaskCompleted) {
            [infoArray addObject:@{
                                   @"block_index":@(task.index),
                                   @"block_size":@(task.size),
                                   @"context":task.context
                                   }];
        }
    }
    return infoArray;
}

- (NSArray *)getContexts {
    
    NSArray *sortedTaskQueueArray = [_taskQueueArray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        QNConcurrentTask *task1 = obj1;
        QNConcurrentTask *task2 = obj2;
        return task1.index > task2.index;
    }];
    NSMutableArray *contextArray = [NSMutableArray arrayWithCapacity:sortedTaskQueueArray.count];
    for (QNConcurrentTask *task in sortedTaskQueueArray) {
        if (task.isTaskCompleted) {
            [contextArray addObject:task.context];
        }
    }
    return contextArray;
}

- (BOOL)isAllCompleted {
    
    BOOL isAllTaskCompleted = YES;
    for (QNConcurrentTask *task in _taskQueueArray) {
        if (!task.isTaskCompleted) {
            isAllTaskCompleted = NO;
            break;
        }
    }
    return isAllTaskCompleted && !_isConcurrentTaskError && !_info && !_resp;
}

- (float)totalPercent {
    
    long long totalUploadSize = 0;
    for (QNConcurrentTask *task in _taskQueueArray) {
        totalUploadSize += task.uploadedSize;
    }
    return totalUploadSize / (float)_totalSize < 0.95 ? totalUploadSize / (float)_totalSize : 0.95;
}

@end

@interface QNConcurrentResumeUpload ()

@property (nonatomic, strong) id<QNRecorderDelegate> recorder;
@property (nonatomic, strong) id<QNFileDelegate> file;
@property (nonatomic, strong) QNConcurrentTaskQueue *taskQueue;

@property (nonatomic, copy) NSString *recorderKey;
@property (nonatomic, strong) NSDictionary *headers;

@property (nonatomic, strong) dispatch_group_t uploadGroup;
@property (nonatomic, strong) dispatch_queue_t uploadQueue;

@property (nonatomic, assign) int64_t modifyTime;
@property (nonatomic, assign, getter=isResettingTaskQueue) BOOL resettingTaskQueue;

@end

@implementation QNConcurrentResumeUpload

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                     withKey:(NSString *)key
                   withToken:(QNUpToken *)token
              withIdentifier:(NSString *)identifier
                withRecorder:(id<QNRecorderDelegate>)recorder
             withRecorderKey:(NSString *)recorderKey
          withSessionManager:(QNSessionManager *)sessionManager
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
           withConfiguration:(QNConfiguration *)config {
    
    if (self = [super init]) {
        self.file = file;
        self.size = (UInt32)[file size];
        self.key = key;
        self.recorder = recorder;
        self.recorderKey = recorderKey;
        self.modifyTime = [file modifyTime];
        self.option = option != nil ? option : [QNUploadOption defaultOptions];
        self.complete = block;
        self.headers = @{@"Authorization" : [NSString stringWithFormat:@"UpToken %@", token.token], @"Content-Type" : @"application/octet-stream"};
        self.config = config;
        self.token = token;
        self.access = token.access;
        self.sessionManager = sessionManager;
        self.identifier = identifier;
        self.resettingTaskQueue = NO;
        self.uploadGroup = dispatch_group_create();
        self.uploadQueue = dispatch_queue_create("com.qiniu.concurrentUpload", DISPATCH_QUEUE_SERIAL);
        
        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
        
        self.taskQueue = [QNConcurrentTaskQueue
                          taskQueueWithFile:file
                          config:config
                          totalSize:self.size
                          recordInfo:[self recoveryFromRecord]
                          token:self.token];
    }
    return self;
}

- (void)run {
    
    for (int i = 0; i < _taskQueue.taskQueueCount; i++) {
        dispatch_group_enter(_uploadGroup);
        dispatch_group_async(_uploadGroup, _uploadQueue, ^{
            [self putBlockWithTask:[self.taskQueue getNextTask] host:self.taskQueue.upHost];
        });
    }
    dispatch_group_notify(_uploadGroup, _uploadQueue, ^{
        if (self.taskQueue.isAllCompleted) {
            [self makeFile];
        } else {
            if (self.isResettingTaskQueue) {
                self.resettingTaskQueue = NO;
                [self removeRecord];
                [self run];
            } else {
                [self collectUploadQualityInfo];
                self.complete(self.taskQueue.info, self.key, self.taskQueue.resp);
            }
       }
    });
}

- (void)retryActionWithType:(QNRequestType)requestType needDelay:(BOOL)needDelay task:(QNConcurrentTask *)task host:(NSString *)host {
    if (needDelay) {
        QNAsyncRunAfter(self.config.retryInterval, self.uploadQueue, ^{
            switch (requestType) {
                case QNRequestType_mkblk:
                    [self putBlockWithTask:task host:host];
                    break;
                    
                case QNRequestType_mkfile:
                    [self makeFile];
                    break;
                    
                default:
                    break;
            }
        });
    } else {
        switch (requestType) {
            case QNRequestType_mkblk:
                [self putBlockWithTask:task host:host];
                break;
                
            case QNRequestType_mkfile:
                [self makeFile];
                break;
                
            default:
                break;
        }
    }
}

- (void)putBlockWithTask:(QNConcurrentTask *)task host:(NSString *)host {
        
    if (self.taskQueue.isConcurrentTaskError) {
        dispatch_group_leave(self.uploadGroup);
        return;
    }
    
    if (self.option.cancellationSignal()) {
        QNResponseInfo *info = [Collector userCancel:self.identifier];
        [self invalidateTasksWithErrorInfo:info resp:nil];
        dispatch_group_leave(self.uploadGroup);
        return;
    }
    
    NSError *error;
    NSData *data = [self.file read:task.index * kQNBlockSize size:task.size error:&error];
    if (error) {
        QNResponseInfo *info = [Collector completeWithFileError:error identifier:self.identifier];
        [self invalidateTasksWithErrorInfo:info resp:nil];
        dispatch_group_leave(self.uploadGroup);
        return;
    }
    
    UInt32 blockCrc = [QNCrc32 data:data];
    
    QNInternalProgressBlock progressBlock = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        if (self.taskQueue.isConcurrentTaskError) return;
        if (totalBytesWritten >= task.uploadedSize) {
            task.uploadedSize = (unsigned int)totalBytesWritten;
        }
        self.option.progressHandler(self.key, self.taskQueue.totalPercent);
    };
    
    QNCompleteBlock completionHandler = ^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        
        [self collectHttpResponseInfo:httpResponseInfo fileOffset:task.index * task.size];
        
        dispatch_async(self.uploadQueue, ^{
            
            if (self.taskQueue.isConcurrentTaskError || self.isResettingTaskQueue) {
                dispatch_group_leave(self.uploadGroup);
                return;
            }
            
            if (httpResponseInfo.error != nil) {
                if (httpResponseInfo.couldRetry) {
                    if (self.taskQueue.retriedTimes < self.config.retryMax) {
                        if ([host isEqualToString:self.taskQueue.upHost]) {
                            self.taskQueue.retriedTimes++;
                        }
                        [self retryActionWithType:QNRequestType_mkblk needDelay:YES task:task host:self.taskQueue.upHost];
                    } else {
                        if (self.config.allowBackupHost) {
                            if (self.taskQueue.recordInfo.host) {
                                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                                [self invalidateTasksWithErrorInfo:info resp:respBody];
                                self.resettingTaskQueue = YES;
                                [self.taskQueue switchZoneWithType:QNZoneInfoTypeMain];
                                dispatch_group_leave(self.uploadGroup);
                            } else {
                                BOOL hasNextHost = [self.taskQueue switchNextHost];
                                if (hasNextHost) {
                                    [self retryActionWithType:QNRequestType_mkblk needDelay:YES task:task host:self.taskQueue.upHost];
                                } else {
                                    QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                                    [self invalidateTasksWithErrorInfo:info resp:respBody];
                                    BOOL hasBackupZone = [self.taskQueue switchZoneWithType:QNZoneInfoTypeBackup];
                                    self.resettingTaskQueue = hasBackupZone;
                                    dispatch_group_leave(self.uploadGroup);
                                }
                            }
                        } else {
                            QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                            [self invalidateTasksWithErrorInfo:info resp:respBody];
                            dispatch_group_leave(self.uploadGroup);
                        }
                    }
                } else {
                    QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                    [self invalidateTasksWithErrorInfo:info resp:respBody];
                    dispatch_group_leave(self.uploadGroup);
                }
            } else {
                NSDictionary *resp = [httpResponseInfo getResponseBody];
                if (resp == nil) {
                    [self retryActionWithType:QNRequestType_mkblk needDelay:YES task:task host:self.taskQueue.upHost];
                } else {
                    NSString *ctx = resp[@"ctx"];
                    NSNumber *crc = resp[@"crc32"];
                    if (ctx == nil || crc == nil || [crc unsignedLongValue] != blockCrc) {
                        [self retryActionWithType:QNRequestType_mkblk needDelay:YES task:task host:self.taskQueue.upHost];
                    } else {
                        self.option.progressHandler(self.key, self.taskQueue.totalPercent);
                        [self record];
                        BOOL hasMore = [self.taskQueue completeTask:task withContext:ctx];
                        if (hasMore) {
                            [self retryActionWithType:QNRequestType_mkblk needDelay:YES task:[self.taskQueue getNextTask] host:self.taskQueue.upHost];
                        } else {
                            dispatch_group_leave(self.uploadGroup);
                        }
                    }
                }
            }
        });
    };
    
    NSString *url = [[NSString alloc] initWithFormat:@"%@/mkblk/%u", host, (unsigned int)task.size];
    [self post:url withData:data withCompleteBlock:completionHandler withProgressBlock:progressBlock];
}

- (void)makeFile {
    
    NSString *mime = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.option.mimeType]];
    
    __block NSString *url = [[NSString alloc] initWithFormat:@"%@/mkfile/%u%@", self.taskQueue.upHost, (unsigned int)self.size, mime];
    
    if (self.key != nil) {
        NSString *keyStr = [[NSString alloc] initWithFormat:@"/key/%@", [QNUrlSafeBase64 encodeString:self.key]];
        url = [NSString stringWithFormat:@"%@%@", url, keyStr];
    }
    
    [self.option.params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        url = [NSString stringWithFormat:@"%@/%@/%@", url, key, [QNUrlSafeBase64 encodeString:obj]];
    }];
    
    //添加路径
    NSString *fname = [[NSString alloc] initWithFormat:@"/fname/%@", [QNUrlSafeBase64 encodeString:[[_file path] lastPathComponent]]];
    url = [NSString stringWithFormat:@"%@%@", url, fname];
    
    NSArray *contextArray = [_taskQueue getContexts];
    NSString *bodyStr = [contextArray componentsJoinedByString:@","];
    NSMutableData *postData = [NSMutableData data];
    [postData appendData:[bodyStr dataUsingEncoding:NSUTF8StringEncoding]];
    
    QNCompleteBlock completionHandler = ^(QNHttpResponseInfo *httpResponseInfo, NSDictionary *respBody) {
        
        [self collectHttpResponseInfo:httpResponseInfo fileOffset:self.size];
        
        dispatch_async(self.uploadQueue, ^{
            if (httpResponseInfo.isOK) {
                [self removeRecord];
                self.option.progressHandler(self.key, 1.0);
                [self collectUploadQualityInfo];
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                self.complete(info, self.key, respBody);
            } else if (httpResponseInfo.couldRetry) {
                if (self.taskQueue.retriedTimes < self.config.retryMax) {
                    self.taskQueue.retriedTimes++;
                    [self retryActionWithType:QNRequestType_mkfile needDelay:YES task:nil host:nil];
                } else {
                    if (self.config.allowBackupHost) {
                        if (self.taskQueue.recordInfo.host) {
                            self.resettingTaskQueue = YES;
                            [self.taskQueue switchZoneWithType:QNZoneInfoTypeMain];
                            [self removeRecord];
                            [self run];
                        } else {
                            BOOL hasNextHost = [self.taskQueue switchNextHost];
                            if (hasNextHost) {
                                [self retryActionWithType:QNRequestType_mkfile needDelay:YES task:nil host:nil];
                            } else {
                                BOOL hasBackupZone = [self.taskQueue switchZoneWithType:QNZoneInfoTypeBackup];
                                if (hasBackupZone) {
                                    [self removeRecord];
                                    [self run];
                                } else {
                                    [self collectUploadQualityInfo];
                                    QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                                    self.complete(info, self.key, respBody);
                                }
                            }
                        }
                    } else {
                        [self collectUploadQualityInfo];
                        QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                        self.complete(info, self.key, respBody);
                    }
                }
            } else {
                [self collectUploadQualityInfo];
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                self.complete(info, self.key, respBody);
            }
        });
    };
    [self post:url withData:postData withCompleteBlock:completionHandler withProgressBlock:nil];
}

- (void)record {
    
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }
    NSNumber *total_size = @(self.size);
    NSNumber *modify_time = [NSNumber numberWithLongLong:_modifyTime];

    QNConcurrentRecorderInfo *recorderInfo = [QNConcurrentRecorderInfo recorderInfoWithTotalSize:total_size
                                                                                      modifyTime:modify_time
                                                                                            host:self.taskQueue.upHost
                                                                                    contextsInfo:[self.taskQueue getRecordInfo]];
    NSError *error;
    NSData *recorderInfoData = [recorderInfo buildRecorderInfoJsonData:&error];
    if (error != nil) {
        NSLog(@"up record json error %@ %@", key, error);
        return;
    }
    error = [self.recorder set:key data:recorderInfoData];
    if (error != nil) {
        NSLog(@"up record set error %@ %@", key, error);
    }
}

- (void)removeRecord {
    if (self.recorder == nil) {
        return;
    }
    [self.recorder del:self.recorderKey];
}

- (QNConcurrentRecorderInfo *)recoveryFromRecord {
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return nil;
    }
    
    NSData *data = [self.recorder get:key];
    if (data == nil) {
        return nil;
    }
    
    NSError *error;
    QNConcurrentRecorderInfo *recordInfo = [QNConcurrentRecorderInfo buildRecorderInfoWithData:data error:&error];
    if (error != nil) {
        NSLog(@"recovery error %@ %@", key, error);
        [self.recorder del:self.key];
        return nil;
    }

    if (recordInfo.totalSize == nil || recordInfo.modifyTime == nil || recordInfo.contextsInfo == nil || recordInfo.contextsInfo.count == 0) {
        return nil;
    }
    
    UInt32 size = [recordInfo.totalSize unsignedIntValue];
    if (size != self.size) {
        return nil;
    }
    
    UInt32 t = [recordInfo.modifyTime unsignedIntValue];
    if (t != self.modifyTime) {
        NSLog(@"modify time changed %u, %llu", (unsigned int)t, self.modifyTime);
        return nil;
    }
    
    return recordInfo;
}

- (void)post:(NSString *)url
    withData:(NSData *)data
withCompleteBlock:(QNCompleteBlock)completeBlock
withProgressBlock:(QNInternalProgressBlock)progressBlock {
    [self.sessionManager post:url withData:data withParams:nil withHeaders:self.headers withIdentifier:self.identifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:self.option.cancellationSignal withAccess:self.access];
}

- (void)invalidateTasksWithErrorInfo:(QNResponseInfo *)info resp:(NSDictionary *)resp {
    if (self.taskQueue.isConcurrentTaskError) return;
    [self.taskQueue buildErrorWithInfo:info resp:resp];
    [self.sessionManager invalidateSessionWithIdentifier:self.identifier];
}

@end
