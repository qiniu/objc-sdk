//
//  QNConcurrentResumeUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/7/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNConcurrentResumeUpload.h"
#import "QNUploadOption.h"
#import "QNConfiguration.h"
#import "QNUpToken.h"
#import "QNResponseInfo.h"
#import "QNUrlSafeBase64.h"
#import "QNCrc32.h"

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
@property (nonatomic, assign) UInt32 totalSize; // 文件总大小
@property (nonatomic, assign) UInt32 concurrentTaskCount; // 用户设置的最大并发任务数量
@property (nonatomic, copy) NSArray *recordInfo; // 续传信息

@property (nonatomic, strong) NSMutableArray<QNConcurrentTask *> *taskQueueArray; // block 任务队列
@property (nonatomic, assign) BOOL isAllCompleted; // completed
@property (nonatomic, assign) float totalPercent; // 上传总进度
@property (nonatomic, assign) UInt32 taskQueueCount; // 实际并发任务数量
@property (atomic, assign) int nextTaskIndex; // 下一个任务的index

@property (nonatomic, assign) BOOL isConcurrentTaskError; // error
@property (nonatomic, strong) QNResponseInfo *info; // errorInfo if error
@property (nonatomic, strong) NSDictionary *resp; // errorResp if error

@property (nonatomic, strong) NSLock *lock;

- (instancetype)init __attribute__((unavailable("use taskQueueWithFile:totalSize:concurrentTaskCount:recordInfo: instead.")));

@end

@implementation QNConcurrentTaskQueue

+ (instancetype)taskQueueWithFile:(id<QNFileDelegate>)file totalSize:(UInt32)totalSize concurrentTaskCount:(UInt32)concurrentTaskCount recordInfo:(NSArray *)recordInfo {
    return [[QNConcurrentTaskQueue alloc] initWithFile:file totalSize:totalSize concurrentTaskCount:concurrentTaskCount recordInfo:recordInfo];
}

- (instancetype)initWithFile:(id<QNFileDelegate>)file totalSize:(UInt32)totalSize concurrentTaskCount:(UInt32)concurrentTaskCount recordInfo:(NSArray *)recordInfo
{
    self = [super init];
    if (self) {
        _file = file;
        _totalSize = totalSize;
        _concurrentTaskCount = concurrentTaskCount;
        _recordInfo = recordInfo;
        
        _taskQueueArray = [NSMutableArray array];
        _isConcurrentTaskError = NO;
        _totalPercent = 0;
        _nextTaskIndex = 0;
        
        _lock = [[NSLock alloc] init];
        
        [self initTaskQueue];
    }
    return self;
}

- (void)initTaskQueue {
    
    // add recover task
    if (_recordInfo.count > 0) {
        for (NSDictionary *info in _recordInfo) {
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
    _taskQueueCount = blockCount > _concurrentTaskCount ? _concurrentTaskCount : blockCount;
    
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
    [_lock lock];
    while (_nextTaskIndex < _taskQueueArray.count) {
        QNConcurrentTask *task = _taskQueueArray[_nextTaskIndex];
        _nextTaskIndex++;
        if (!task.isTaskCompleted) {
            nextTask = task;
            break;
        }
    }
    [_lock unlock];
    return nextTask;
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
    
    [_lock lock];
    BOOL hasMore = _nextTaskIndex < _taskQueueArray.count;
    [_lock unlock];
    return hasMore;
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

@property (nonatomic, strong) id<QNHttpDelegate> httpManager;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSDictionary *headers;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic, strong) QNUpCompletionHandler complete;
@property (nonatomic, strong) id<QNRecorderDelegate> recorder;
@property (nonatomic, copy) NSString *recorderKey;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id<QNFileDelegate> file;
@property (nonatomic, copy) NSString *access; //AK
@property (nonatomic, strong) dispatch_group_t uploadGroup;
@property (nonatomic, strong) QNConcurrentTaskQueue *taskQueue;
@property (nonatomic, copy) NSString *taskIdentifier;
@property (nonatomic, assign) UInt32 size;
@property (nonatomic, assign) int64_t modifyTime;

@end

@implementation QNConcurrentResumeUpload

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                     withKey:(NSString *)key
                   withToken:(QNUpToken *)token
                withRecorder:(id<QNRecorderDelegate>)recorder
             withRecorderKey:(NSString *)recorderKey
             withHttpManager:(id<QNHttpDelegate>)http
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
           withConfiguration:(QNConfiguration *)config {
    
    if (self = [super init]) {
        _file = file;
        _size = (UInt32)[file size];
        _key = key;
        _recorder = recorder;
        _recorderKey = recorderKey;
        _modifyTime = [file modifyTime];
        _option = option != nil ? option : [QNUploadOption defaultOptions];
        _complete = block;
        _headers = @{@"Authorization" : [NSString stringWithFormat:@"UpToken %@", token.token], @"Content-Type" : @"application/octet-stream"};
        _config = config;
        _token = token;
        _access = token.access;
        _httpManager = http;
        _taskIdentifier = [[NSUUID UUID] UUIDString];
        
        _taskQueue = [QNConcurrentTaskQueue taskQueueWithFile:file totalSize:_size concurrentTaskCount:_config.concurrentTaskCount recordInfo:[self recoveryFromRecord]];
    }
    return self;
}

- (void)run {
    
    _uploadGroup = dispatch_group_create();
    for (int i = 0; i < _taskQueue.taskQueueCount; i++) {
        dispatch_group_enter(_uploadGroup);
        dispatch_group_async(_uploadGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self putBlockWithHost:[self.config.zone up:self.token isHttps:self.config.useHttps frozenDomain:nil] taskQueue:[self.taskQueue getNextTask] retriedTimes:0];
        });
    }
    dispatch_group_notify(_uploadGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.taskQueue.isAllCompleted) {
            [self makeFileWithHost:[self.config.zone up:self.token isHttps:self.config.useHttps frozenDomain:nil] retriedTimes:0];
        } else {
            self.complete(self.taskQueue.info, self.key, self.taskQueue.resp);
       }
    });
}

- (void)putBlockWithHost:(NSString *)uphost taskQueue:(QNConcurrentTask *)task retriedTimes:(int)retried {
    
    if (_taskQueue.isConcurrentTaskError) {
        dispatch_group_leave(self.uploadGroup);
        return;
    }
    
    if (self.option.cancellationSignal()) {
        [self invalidateTasksWithErrorInfo:[QNResponseInfo cancel] resp:nil];
        dispatch_group_leave(self.uploadGroup);
        return;
    }
    
    NSError *error;
    NSData *data = [self.file read:task.index * kQNBlockSize size:task.size error:&error];
    if (error) {
        self.complete([QNResponseInfo responseInfoWithFileError:error], self.key, nil);
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
    
    QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
        if (info.error != nil) {
            if (retried >= self.config.retryMax || !info.couldRetry) {
                [self invalidateTasksWithErrorInfo:info resp:resp];
                dispatch_group_leave(self.uploadGroup);
                return;
            }
            
            NSString *nextHost = uphost;
            if (info.isConnectionBroken || info.needSwitchServer) {
                nextHost = [self.config.zone up:self.token isHttps:self.config.useHttps frozenDomain:nextHost];
            }
            [self putBlockWithHost:nextHost taskQueue:task retriedTimes:retried + 1];
            return;
        }
        
        if (resp == nil) {
            [self putBlockWithHost:uphost taskQueue:task retriedTimes:retried];
            return;
        }
        
        NSString *ctx = resp[@"ctx"];
        NSNumber *crc = resp[@"crc32"];
        if (ctx == nil || crc == nil || [crc unsignedLongValue] != blockCrc) {
            [self putBlockWithHost:uphost taskQueue:task retriedTimes:retried];
            return;
        }
        
        BOOL hasMore = [self.taskQueue completeTask:task withContext:ctx];
        self.option.progressHandler(self.key, self.taskQueue.totalPercent);
        [self record];
        if (hasMore) {
            [self putBlockWithHost:uphost taskQueue:[self.taskQueue getNextTask] retriedTimes:retried];
        } else {
            dispatch_group_leave(self.uploadGroup);
        }
    };
    
    NSString *url = [[NSString alloc] initWithFormat:@"%@/mkblk/%u", uphost, (unsigned int)task.size];
    [self post:url withData:data withCompleteBlock:completionHandler withProgressBlock:progressBlock];
}

- (void)makeFileWithHost:(NSString *)uphost retriedTimes:(int)retried {
    
    NSString *mime = [[NSString alloc] initWithFormat:@"/mimeType/%@", [QNUrlSafeBase64 encodeString:self.option.mimeType]];
    
    __block NSString *url = [[NSString alloc] initWithFormat:@"%@/mkfile/%u%@", uphost, (unsigned int)self.size, mime];
    
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
    
    QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
        if (info.isOK) {
            [self removeRecord];
            self.option.progressHandler(self.key, 1.0);
        } else if (info.couldRetry && retried < self.config.retryMax) {
            [self makeFileWithHost:uphost retriedTimes:retried + 1];
            return;
        }
        self.complete(info, self.key, resp);
    };
    [self post:url withData:postData withCompleteBlock:completionHandler withProgressBlock:nil];
}

- (void)record {
    
    NSString *key = self.recorderKey;
    if (_recorder == nil || key == nil || [key isEqualToString:@""]) {
        return;
    }
    NSNumber *total_size = @(self.size);
    NSNumber *modify_time = [NSNumber numberWithLongLong:_modifyTime];
    NSMutableDictionary *rec = [NSMutableDictionary dictionaryWithObjectsAndKeys:total_size, @"total_size", modify_time, @"modify_time", [_taskQueue getRecordInfo], @"info", nil];
    
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:rec options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"up record json error %@ %@", key, error);
        return;
    }
    error = [_recorder set:key data:data];
    if (error != nil) {
        NSLog(@"up record set error %@ %@", key, error);
    }
}

- (void)removeRecord {
    if (_recorder == nil) {
        return;
    }
    [_recorder del:self.recorderKey];
}

- (NSArray *)recoveryFromRecord {
    NSString *key = self.recorderKey;
    if (_recorder == nil || key == nil || [key isEqualToString:@""]) {
        return nil;
    }
    
    NSData *data = [_recorder get:key];
    if (data == nil) {
        return nil;
    }
    
    NSError *error;
    NSDictionary *recordInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    if (error != nil) {
        NSLog(@"recovery error %@ %@", key, error);
        [_recorder del:self.key];
        return nil;
    }
    NSNumber *total_size = recordInfo[@"total_size"];
    NSNumber *modify_time = recordInfo[@"modify_time"];
    NSArray *info = recordInfo[@"info"];
    if (total_size == nil || modify_time == nil || info == nil || info.count == 0) {
        return nil;
    }
    
    UInt32 size = [total_size unsignedIntValue];
    if (size != self.size) {
        return nil;
    }
    
    UInt32 t = [modify_time unsignedIntValue];
    if (t != _modifyTime) {
        NSLog(@"modify time changed %u, %llu", (unsigned int)t, _modifyTime);
        return nil;
    }
    
    return info;
}

- (void)post:(NSString *)url
    withData:(NSData *)data
withCompleteBlock:(QNCompleteBlock)completeBlock
withProgressBlock:(QNInternalProgressBlock)progressBlock {
    [_httpManager post:url withData:data withParams:nil withHeaders:_headers withTaskIdentifier:_taskIdentifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:_option.cancellationSignal withAccess:_access];
}

- (void)invalidateTasksWithErrorInfo:(QNResponseInfo *)info resp:(NSDictionary *)resp {
    if (_taskQueue.isConcurrentTaskError) return;
    [_taskQueue buildErrorWithInfo:info resp:resp];
    [_httpManager invalidateSessionWithIdentifier:_taskIdentifier];
}

@end
