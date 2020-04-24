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
@property (nonatomic, strong) NSNumber *offset;         // offset of next block
@property (nonatomic, strong) NSNumber *modifyTime;  // modify time of the file
@property (nonatomic, copy) NSString *host;          // upload host used last time
@property (nonatomic, strong) NSArray<NSDictionary *> *contextsInfo;  // concurrent upload contexts info

- (instancetype)init __attribute__((unavailable("use recorderInfoWithTotalSize:offset:totalSize:modifyTime:host:contextsInfo: instead.")));

@end

@implementation QNConcurrentRecorderInfo

+ (instancetype)recorderInfoWithTotalSize:(NSNumber *)totalSize offset:(NSNumber *)offset modifyTime:(NSNumber *)modifyTime host:(NSString *)host contextsInfo:(NSArray<NSDictionary *> *)contextsInfo {
    return [[QNConcurrentRecorderInfo alloc] initWithTotalSize:totalSize offset:offset modifyTime:modifyTime host:host contextsInfo:contextsInfo];
}

- (instancetype)initWithTotalSize:(NSNumber *)totalSize offset:(NSNumber *)offset modifyTime:(NSNumber *)modifyTime host:(NSString *)host contextsInfo:(NSArray<NSDictionary *> *)contextsInfo {
    
    self = [super init];
    if (self) {
        _totalSize = totalSize ? totalSize : @0;
        _offset = offset ? offset : @0;
        _modifyTime = modifyTime ? modifyTime : @0;
        _host = host ? host : @"";
        _contextsInfo = contextsInfo ? contextsInfo : @[];
    }
    return self;
}

- (NSData *)buildRecorderInfoJsonData:(NSError **)error {
    
    NSDictionary *recorderInfo = @{
        @"total_size": _totalSize,
        @"off_set": _offset,
        @"modify_time": _modifyTime,
        @"host": _host,
        @"contexts_info": _contextsInfo
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:recorderInfo options:NSJSONWritingPrettyPrinted error:error];
    return data;
}

+ (QNConcurrentRecorderInfo *)buildRecorderInfoWithData:(NSData *)data error:(NSError **)error {
    
    NSDictionary *recorderInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:error];
    return [[self class] recorderInfoWithTotalSize:recorderInfo[@"total_size"] offset:recorderInfo[@"off_set"] modifyTime:recorderInfo[@"modify_time"] host:recorderInfo[@"host"] contextsInfo:recorderInfo[@"contexts_info"]];
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

@property (nonatomic, strong) NSArray<NSDictionary *> *contextsInfo; // 续传context信息
@property (nonatomic, assign) UInt32 offset;  // 断点续传偏移量

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
                     contextsInfo:(NSArray<NSDictionary *> *)contextsInfo
                            token:(QNUpToken *)token {
    
    return [[QNConcurrentTaskQueue alloc] initWithFile:file
                                                config:config
                                             totalSize:totalSize
                                          contextsInfo:contextsInfo
                                                 token:token];
}

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                      config:(QNConfiguration *)config
                   totalSize:(UInt32)totalSize
                contextsInfo:(NSArray<NSDictionary *> *)contextsInfo
                       token:(QNUpToken *)token {
    
    self = [super init];
    if (self) {
        _file = file;
        _config = config;
        _totalSize = totalSize;
        _contextsInfo = contextsInfo;
        _token = token;
                
        _taskQueueArray = [NSMutableArray array];
        _isConcurrentTaskError = NO;
        _nextTaskIndex = 0;
        _taskQueueCount = 0;
        _offset = 0;
                
        [self initTaskQueue];
    }
    return self;
}

- (void)initTaskQueue {
    
    // add recover task
    if (_contextsInfo.count > 0) {
        for (NSDictionary *info in _contextsInfo) {
            int block_index = [info[@"block_index"] intValue];
            UInt32 block_size = [info[@"block_size"] unsignedIntValue];
            NSString *context = info[@"context"];
            _offset += block_size;
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

- (void)reset {
    
    // reset
    _contextsInfo = nil;
    _resp = nil;
    _info = nil;
    _nextTaskIndex = 0;
    _taskQueueCount = 0;
    _offset = 0;
    _isConcurrentTaskError = NO;
    [_taskQueueArray removeAllObjects];
    
    [self initTaskQueue];
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
@property (nonatomic, strong) QNConcurrentRecorderInfo *recordInfo; // 续传信息

@property (nonatomic, copy) NSString *recorderKey;
@property (nonatomic, strong) NSDictionary *headers;

@property (nonatomic, strong) dispatch_group_t uploadGroup;
@property (nonatomic, strong) dispatch_queue_t uploadQueue;

@property (nonatomic, copy) NSString *upHost;
@property (nonatomic, assign) UInt32 retriedTimes; // 当前域名重试次数

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
        self.retriedTimes = 0;
        self.currentZoneType = QNZoneInfoTypeMain;
        self.uploadGroup = dispatch_group_create();
        self.uploadQueue = dispatch_queue_create("com.qiniu.concurrentUpload", DISPATCH_QUEUE_SERIAL);
        
        self.recordInfo = [self recoveryFromRecord];
        self.taskQueue = [QNConcurrentTaskQueue
                          taskQueueWithFile:file
                          config:config
                          totalSize:self.size
                          contextsInfo:self.recordInfo.contextsInfo
                          token:self.token];
        
        [Collector update:CK_blockApiVersion value:@1 identifier:self.identifier];
        [Collector update:CK_recoveredFrom value:self.recordInfo.offset ? self.recordInfo.offset : @0  identifier:self.identifier];
    }
    return self;
}

- (void)run {
    
    self.requestType = QNRequestType_mkblk;
    if (self.recordInfo.host && ![self.recordInfo.host isEqualToString:@""]) {
        self.upHost = self.recordInfo.host;
    } else {
        self.upHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:nil];
    }
    for (int i = 0; i < _taskQueue.taskQueueCount; i++) {
        dispatch_group_enter(_uploadGroup);
        dispatch_group_async(_uploadGroup, _uploadQueue, ^{
            [self putBlockWithTask:[self.taskQueue getNextTask] host:self.upHost];
        });
    }
    dispatch_group_notify(_uploadGroup, _uploadQueue, ^{
        if (self.taskQueue.isAllCompleted) {
            self.requestType = QNRequestType_mkfile;
            [self makeFile];
        } else {
            if (self.isResettingTaskQueue) {
                self.resettingTaskQueue = NO;
                [self removeRecord];
                [self.taskQueue reset];
                [self run];
            } else {
                self.complete(self.taskQueue.info, self.key, self.taskQueue.resp);
            }
       }
    });
}

- (void)retryWithDelay:(BOOL)needDelay task:(QNConcurrentTask *)task host:(NSString *)host {
    if (needDelay) {
        QNAsyncRunAfter(self.config.retryInterval, self.uploadQueue, ^{
            switch (self.requestType) {
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
        switch (self.requestType) {
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
                
    if (self.option.cancellationSignal()) {
        [self collectUploadQualityInfo];
        QNResponseInfo *info = [Collector userCancel:self.identifier];
        [self invalidateTasksWithErrorInfo:info resp:nil];
        dispatch_group_leave(self.uploadGroup);
        return;
    }
    
    NSError *error;
    NSData *data = [self.file read:task.index * kQNBlockSize size:task.size error:&error];
    if (error) {
        [self collectUploadQualityInfo];
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
        dispatch_async(self.uploadQueue, ^{
            if (self.taskQueue.isConcurrentTaskError) {
                dispatch_group_leave(self.uploadGroup);
                return;
            }
            
            [self collectHttpResponseInfo:httpResponseInfo fileOffset:task.index * task.size];
            
            NSString *ctx = respBody[@"ctx"];
            NSNumber *crc = respBody[@"crc32"];
            if (httpResponseInfo.isOK && ctx && crc && [crc unsignedLongValue] == blockCrc) {
                self.option.progressHandler(self.key, self.taskQueue.totalPercent);
                [self recordWithTask:task];
                BOOL hasMore = [self.taskQueue completeTask:task withContext:ctx];
                if (hasMore) {
                    [self retryWithDelay:YES task:[self.taskQueue getNextTask] host:self.upHost];
                } else {
                    dispatch_group_leave(self.uploadGroup);
                }
            } else if (httpResponseInfo.couldRetry) {
                if (self.retriedTimes < self.config.retryMax) {
                    if ([host isEqualToString:self.upHost]) {
                        self.retriedTimes++;
                    }
                    [self retryWithDelay:YES task:task host:self.upHost];
                } else {
                    self.retriedTimes = 0;
                    if (self.config.allowBackupHost) {
                        if (self.recordInfo.host) {
                            self.currentZoneType = QNZoneInfoTypeMain;
                            [self invalidateTasksWithErrorInfo:nil resp:nil];
                            self.resettingTaskQueue = YES;
                            dispatch_group_leave(self.uploadGroup);
                        } else {
                            NSString *nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:host];
                            if (nextHost) {
                                self.upHost = nextHost;
                                [self retryWithDelay:YES task:task host:self.upHost];
                            } else {
                                QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                                if (self.currentZoneType == QNZoneInfoTypeMain && zonesInfo.hasBackupZone) {
                                    self.currentZoneType = QNZoneInfoTypeBackup;
                                    [self invalidateTasksWithErrorInfo:nil resp:nil];
                                    self.resettingTaskQueue = YES;
                                } else {
                                    [self collectUploadQualityInfo];
                                    QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                                    [self invalidateTasksWithErrorInfo:info resp:respBody];
                                }
                                dispatch_group_leave(self.uploadGroup);
                            }
                        }
                    } else {
                        [self collectUploadQualityInfo];
                        QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                        [self invalidateTasksWithErrorInfo:info resp:respBody];
                        dispatch_group_leave(self.uploadGroup);
                    }
                }
            } else {
                [self collectUploadQualityInfo];
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                [self invalidateTasksWithErrorInfo:info resp:respBody];
                dispatch_group_leave(self.uploadGroup);
            }
        });
    };
    NSString *url = [[NSString alloc] initWithFormat:@"%@/mkblk/%u", host, (unsigned int)task.size];
    [self post:url withData:data withCompleteBlock:completionHandler withProgressBlock:progressBlock];
}

- (void)makeFile {
    
    NSString *mime = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.option.mimeType]];
    
    __block NSString *url = [[NSString alloc] initWithFormat:@"%@/mkfile/%u%@", self.upHost, (unsigned int)self.size, mime];
    
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
        dispatch_async(self.uploadQueue, ^{
            [self collectHttpResponseInfo:httpResponseInfo fileOffset:self.size];
            
            if (httpResponseInfo.isOK) {
                [self removeRecord];
                self.option.progressHandler(self.key, 1.0);
                [self collectUploadQualityInfo];
                QNResponseInfo *info = [Collector completeWithHttpResponseInfo:httpResponseInfo identifier:self.identifier];
                self.complete(info, self.key, respBody);
            } else if (httpResponseInfo.couldRetry) {
                if (self.retriedTimes < self.config.retryMax) {
                    self.retriedTimes++;
                    [self retryWithDelay:YES task:nil host:nil];
                } else {
                    self.retriedTimes = 0;
                    if (self.config.allowBackupHost) {
                        if (self.recordInfo.host) {
                            self.currentZoneType = QNZoneInfoTypeMain;
                            [self.taskQueue reset];
                            [self removeRecord];
                            [self run];
                        } else {
                            NSString *nextHost = [self.config.zone up:self.token zoneInfoType:self.currentZoneType isHttps:self.config.useHttps frozenDomain:self.upHost];
                            if (nextHost) {
                                self.upHost = nextHost;
                                [self retryWithDelay:YES task:nil host:nil];
                            } else {
                                QNZonesInfo *zonesInfo = [self.config.zone getZonesInfoWithToken:self.token];
                                if (self.currentZoneType == QNZoneInfoTypeMain && zonesInfo.hasBackupZone) {
                                    self.currentZoneType = QNZoneInfoTypeBackup;
                                    [self.taskQueue reset];
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

- (void)recordWithTask:(QNConcurrentTask *)task {
    
    NSString *key = self.recorderKey;
    if (self.recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }
    NSNumber *total_size = @(self.size);
    NSNumber *modify_time = [NSNumber numberWithLongLong:_modifyTime];
    NSNumber *off_set = [NSNumber numberWithUnsignedInt:(task.index + 1) * task.size];

    QNConcurrentRecorderInfo *recorderInfo = [QNConcurrentRecorderInfo recorderInfoWithTotalSize:total_size
                                                                                          offset:off_set
                                                                                      modifyTime:modify_time
                                                                                            host:self.upHost
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
    self.recordInfo = nil;
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

    if (recordInfo.totalSize == nil || recordInfo.offset == nil || recordInfo.modifyTime == nil || recordInfo.contextsInfo == nil || recordInfo.contextsInfo.count == 0) {
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
