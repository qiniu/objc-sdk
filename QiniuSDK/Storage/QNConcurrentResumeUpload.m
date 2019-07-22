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
#import "QNCommonTool.h"

@interface QNConcurrentTask: NSObject
@property (nonatomic, readonly, strong) NSMutableArray *blockArray;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, readonly, assign) NSInteger uploadingIndex;
@property (nonatomic, readonly, assign) BOOL isCompleted;

@property (nonatomic, readonly, strong) NSString *currentIndex;
@property (nonatomic, readonly, assign) UInt32 currentSize;
@property (nonatomic, readonly, assign) float currentPercent;

@end

@implementation QNConcurrentTask

- (instancetype)init
{
    self = [super init];
    if (self) {
        _blockArray = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
        _uploadingIndex = 0;
    }
    return self;
}

- (void)joinWithBlockIndex:(int)index
                 blockSize:(UInt32)size {
    
    [_blockArray addObject:[@{@"blockIndex": [NSString stringWithFormat:@"%d", index],
                             @"blockSize": [NSString stringWithFormat:@"%u", (unsigned int)size],
                             @"uploadPercent": @"0"
                             } mutableCopy]];
}

- (BOOL)finishCurrent {
    
    self.currentPercent = 1;
    _uploadingIndex++;
    return self.isCompleted;
}

- (BOOL)isCompleted {
    BOOL isCompleted = YES;
    for (NSDictionary *blockInfo in _blockArray) {
        if ([blockInfo[@"uploadPercent"] floatValue] < 1) {
            isCompleted = NO;
            break;
        }
    }
    return isCompleted;
}

- (NSString *)currentIndex {
    return _blockArray[_uploadingIndex][@"blockIndex"];
}

- (UInt32)currentSize {
    return (unsigned int)[_blockArray[_uploadingIndex][@"blockSize"] longLongValue];
}

- (void)setCurrentPercent:(float)currentPercent {
    [_lock lock];
    _blockArray[_uploadingIndex][@"uploadPercent"] = [NSString stringWithFormat:@"%f", currentPercent];
    [_lock unlock];
}

@end

@interface QNConcurrentTaskQueue: NSObject

@property (nonatomic, strong) NSMutableArray<QNConcurrentTask *> *taskQueueArray;

@property (nonatomic, strong) QNResponseInfo *info;

@property (nonatomic, strong) NSDictionary *resp;

@property (nonatomic, assign) BOOL isConcurrentTaskError;

@property (nonatomic, assign) BOOL isAllCompleted;

@property (nonatomic, strong) id<QNFileDelegate> file;

@property (nonatomic, assign) UInt32 totalSize;

@property (nonatomic, assign) UInt32 concurrentTaskCount;

@property (nonatomic, assign) float totalPercent;

@end

@implementation QNConcurrentTaskQueue

+ (instancetype)taskQueueWithFile:(id<QNFileDelegate>)file totalSize:(UInt32)totalSize concurrentTaskCount:(UInt32)concurrentTaskCount {
    return [[QNConcurrentTaskQueue alloc] initWithFile:file totalSize:totalSize concurrentTaskCount:concurrentTaskCount];
}

- (instancetype)initWithFile:(id<QNFileDelegate>)file totalSize:(UInt32)totalSize concurrentTaskCount:(UInt32)concurrentTaskCount
{
    self = [super init];
    if (self) {
        _file = file;
        _totalSize = totalSize;
        _concurrentTaskCount = concurrentTaskCount;
        
        _taskQueueArray = [NSMutableArray array];
        _isConcurrentTaskError = NO;
        _totalPercent = 0;
        
        [self initTaskQueue];
    }
    return self;
}

- (void)initTaskQueue {
    
    int blockCount = _totalSize % kQNBlockSize == 0 ? _totalSize / kQNBlockSize : _totalSize / kQNBlockSize + 1;
    int taskQueueCount = blockCount > _concurrentTaskCount ? _concurrentTaskCount : blockCount;
    
    for (int i = 0; i < taskQueueCount; i++) {
        QNConcurrentTask *task = [[QNConcurrentTask alloc] init];
        for (int j = 0; j < blockCount; j++) {
            if (j % taskQueueCount == i) {
                UInt32 left = _totalSize - j * kQNBlockSize;
                UInt32 blockSize = left < kQNBlockSize ? left : kQNBlockSize;
                [task joinWithBlockIndex:j blockSize:blockSize];
            }
        }
        [_taskQueueArray addObject:task];
    }
}

- (void)buildErrorWithInfo:(QNResponseInfo *)info resp:(NSDictionary *)resp {
    
    if (_isConcurrentTaskError) return;
    _isConcurrentTaskError = YES;
    _info = info;
    _resp = resp;
}

- (BOOL)isAllCompleted {
    
    BOOL isAllTaskCompleted = YES;
    for (QNConcurrentTask *task in _taskQueueArray) {
        if (task.blockArray.count > 0) {
            isAllTaskCompleted = NO;
            break;
        }
    }
    return isAllTaskCompleted && !_isConcurrentTaskError && !_info && !_resp;
}

- (float)totalPercent {
    
    long long totalUploadSize = 0;
    for (QNConcurrentTask *task in _taskQueueArray) {
        [task.lock lock];
        for (NSDictionary *blockInfo in task.blockArray) {
            float uploadPercent = [blockInfo[@"uploadPercent"] floatValue];
            UInt32 blockTotalSize = [blockInfo[@"blockSize"] floatValue];
            totalUploadSize += uploadPercent * blockTotalSize;
        }
        [task.lock unlock];
    }
    return totalUploadSize / (float)_totalSize < 0.95 ? totalUploadSize / (float)_totalSize : 0.95;
}

@end

@interface QNConcurrentResumeUpload ()

@property (nonatomic, strong) id<QNHttpDelegate> httpManager;
@property UInt32 size;
@property (nonatomic, strong) NSString *key;
@property (nonatomic) NSDictionary *headers;
@property (nonatomic, strong) QNUploadOption *option;
@property (nonatomic, strong) QNUpToken *token;
@property (nonatomic, strong) QNUpCompletionHandler complete;
@property (nonatomic, strong) NSMutableDictionary *contexts;
@property (nonatomic, strong) id<QNRecorderDelegate> recorder;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) id<QNFileDelegate> file;
@property (nonatomic) float previousPercent;
@property (nonatomic, strong) NSString *access; //AK
@property (nonatomic, strong) dispatch_group_t uploadGroup;
@property (nonatomic, strong) QNConcurrentTaskQueue *taskQueue;
@property (nonatomic, copy) NSString *taskIdentifier;

@end

@implementation QNConcurrentResumeUpload

- (instancetype)initWithFile:(id<QNFileDelegate>)file
                     withKey:(NSString *)key
                   withToken:(QNUpToken *)token
             withHttpManager:(id<QNHttpDelegate>)http
       withCompletionHandler:(QNUpCompletionHandler)block
                  withOption:(QNUploadOption *)option
           withConfiguration:(QNConfiguration *)config {
    
    if (self = [super init]) {
        _file = file;
        _size = (UInt32)[file size];
        _key = key;
        NSString *tokenUp = [NSString stringWithFormat:@"UpToken %@", token.token];
        _option = option != nil ? option : [QNUploadOption defaultOptions];
        _complete = block;
        _headers = @{@"Authorization" : tokenUp, @"Content-Type" : @"application/octet-stream"};
        _config = config;
        _token = token;
        _previousPercent = 0;
        _access = token.access;
        _httpManager = http;
        _taskQueue = [QNConcurrentTaskQueue taskQueueWithFile:file totalSize:_size concurrentTaskCount:_config.concurrentTaskCount];
        _contexts = [[NSMutableDictionary alloc] initWithCapacity:(_size + kQNBlockSize - 1) / kQNBlockSize];
        _taskIdentifier = [QNCommonTool getRandomStringWithLength:32];
    }
    return self;
}

- (void)run {
    
    _uploadGroup = dispatch_group_create();
    for (int i = 0; i < _taskQueue.taskQueueArray.count; i++) {
        dispatch_group_enter(_uploadGroup);
        dispatch_group_async(_uploadGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self putBlockWithHost:[self.config.zone up:self.token isHttps:self.config.useHttps frozenDomain:nil] taskQueue:self.taskQueue.taskQueueArray[i] retriedTimes:0];
        });
    }
    dispatch_group_notify(_uploadGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.taskQueue.isConcurrentTaskError) {
            self.complete(self.taskQueue.info, self.key, self.taskQueue.resp);
        } else {
            [self makeFileWithHost:[self.config.zone up:self.token isHttps:self.config.useHttps frozenDomain:nil] retriedTimes:0];
        }
    });
}

- (void)putBlockWithHost:(NSString *)uphost taskQueue:(QNConcurrentTask *)task retriedTimes:(int)retried {
    
    if (_taskQueue.isConcurrentTaskError) return;
    
    if (self.option.cancellationSignal()) {
        [_taskQueue buildErrorWithInfo:[QNResponseInfo cancel] resp:nil];
        return;
    }
    
    NSData *data = [self.file read:task.currentIndex.intValue * kQNBlockSize size:task.currentSize];
    UInt32 blockCrc = [QNCrc32 data:data];
    
    QNInternalProgressBlock progressBlock = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        task.currentPercent = totalBytesWritten / (float)task.currentSize;
        self.option.progressHandler(self.key, self.taskQueue.totalPercent);
    };
    
    QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
        if (info.error != nil) {
            if (retried >= self.config.retryMax || !info.couldRetry) {
                [self.taskQueue buildErrorWithInfo:info resp:resp];
                [self cancelTasks];
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
        
        self.contexts[task.currentIndex] = ctx;
        BOOL isTaskCompleted = [task finishCurrent];
        if (isTaskCompleted) {
            self.option.progressHandler(self.key, self.taskQueue.totalPercent);
            dispatch_group_leave(self.uploadGroup);
        } else {
            [self putBlockWithHost:uphost taskQueue:task retriedTimes:retried];
        }
    };
    
    NSString *url = [[NSString alloc] initWithFormat:@"%@/mkblk/%u", uphost, task.currentSize];
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
    
    //contexts排序
    NSArray *sortedKeys = [[_contexts allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 intValue] > [obj2 intValue];
    }];
    NSMutableArray *sortedContexts = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        NSString *context = _contexts[key];
        [sortedContexts addObject:context];
    };
    
    NSMutableData *postData = [NSMutableData data];
    NSString *bodyStr = [sortedContexts componentsJoinedByString:@","];
    [postData appendData:[bodyStr dataUsingEncoding:NSUTF8StringEncoding]];
    
    QNCompleteBlock completionHandler = ^(QNResponseInfo *info, NSDictionary *resp) {
        if (info.isOK) {
            self.option.progressHandler(self.key, 1.0);
        } else if (info.couldRetry && retried < self.config.retryMax) {
            [self makeFileWithHost:uphost retriedTimes:retried + 1];
            return;
        }
        self.complete(info, self.key, resp);
    };
    [self post:url withData:postData withCompleteBlock:completionHandler withProgressBlock:nil];
}

- (void)post:(NSString *)url
    withData:(NSData *)data
withCompleteBlock:(QNCompleteBlock)completeBlock
withProgressBlock:(QNInternalProgressBlock)progressBlock {
    [_httpManager post:url withData:data withParams:nil withHeaders:_headers withTaskIdentifier:_taskIdentifier withCompleteBlock:completeBlock withProgressBlock:progressBlock withCancelBlock:_option.cancellationSignal withAccess:_access];
}

- (void)cancelTasks {
    [_httpManager cancelSessionWithIdentifier:_taskIdentifier];
}

@end
