//
//  QNUploadInfoCollector.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadInfoCollector.h"
#import "QNUploadInfoReporter.h"
#import "QNHttpResponseInfo.h"
#import "QNResponseInfo.h"

QNCollectKey *const CK_bucket = @"bucket";
QNCollectKey *const CK_key = @"key";
QNCollectKey *const CK_targetRegionId = @"targetRegionId";
QNCollectKey *const CK_currentRegionId = @"currentRegionId";
QNCollectKey *const CK_result = @"result";
QNCollectKey *const CK_blockBytesSent = @"blockBytesSent";
QNCollectKey *const CK_recoveredFrom = @"recoveredFrom";
QNCollectKey *const CK_totalBytesSent = @"totalBytesSent";
QNCollectKey *const CK_fileSize = @"fileSize";
QNCollectKey *const CK_blockApiVersion = @"blockApiVersion";

int64_t QN_IntNotSet = -11111111;

// Upload Result Type
NSString *const upload_ok = @"ok";
NSString *const zero_size_file = @"zero_size_file";
NSString *const invalid_file = @"invalid_file";
NSString *const invalid_args = @"invalid_args";
NSString *const local_io_error = @"local_io_error";

// Network Error Type
NSString *const unknown_error = @"unknown_error";
NSString *const network_error = @"network_error";
NSString *const network_timeout = @"timeout";
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

static NSString *const requestTypes[] = {@"form", @"mkblk", @"bput", @"mkfile", @"put", @"init_parts", @"upload_part", @"complete_part", @"uc_query", @"httpdns_query"};

@interface QNCollectItem : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *bucket;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *targetRegionId;
@property (nonatomic, copy) NSString *currentRegionId;
@property (nonatomic, copy) NSString *result;

@property (nonatomic, assign) int64_t uploadStartTime;
@property (nonatomic, assign) int64_t uploadEndTime;
@property (nonatomic, assign) int64_t totalBytesSent;
@property (nonatomic, assign) int64_t fileSize;

@property (nonatomic, assign) int64_t recoveredFrom;
@property (nonatomic, assign) int64_t blockApiVersion;
@property (nonatomic, assign) int64_t blockBytesSent;

@property (nonatomic, strong) NSMutableArray<QNHttpResponseInfo *> *httpRequestList;
@end

@implementation QNCollectItem

- (instancetype)initWithIdentifier:(NSString *)identifier token:(NSString *)token
{
    self = [super init];
    if (self) {
        _identifier = identifier;
        _token = token;
        _uploadStartTime = QN_IntNotSet;
        _uploadEndTime = QN_IntNotSet;
        _fileSize = QN_IntNotSet;
        _recoveredFrom = QN_IntNotSet;
        _blockApiVersion = QN_IntNotSet;
        _totalBytesSent = 0;
        _blockBytesSent = 0;
        _httpRequestList = [NSMutableArray array];
    }
    return self;
}

@end

@interface QNUploadInfoCollector ()
@property (nonatomic, strong) NSArray<QNCollectKey *> *updateKeysList;
@property (nonatomic, strong) NSArray <QNCollectKey *>*appendKeysList;
@property (nonatomic, strong) NSMutableArray<QNCollectItem *> *collectItemList;
@property (nonatomic, strong) dispatch_queue_t collectQueue;
@end

@implementation QNUploadInfoCollector
+ (instancetype)sharedInstance {
    
    static QNUploadInfoCollector *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.collectItemList = [NSMutableArray array];
        sharedInstance.collectQueue = dispatch_queue_create("com.qiniu.collector", DISPATCH_QUEUE_SERIAL);
        sharedInstance.updateKeysList = @[
            CK_bucket,
            CK_key,
            CK_targetRegionId,
            CK_currentRegionId,
            CK_result,
            CK_recoveredFrom,
            CK_fileSize,
            CK_blockApiVersion];
        sharedInstance.appendKeysList = @[
            CK_blockBytesSent,
            CK_totalBytesSent];
    });
    return sharedInstance;
}

- (void)registerWithIdentifier:(NSString *)identifier token:(NSString *)token {
    if (!identifier || !token) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *item = [[QNCollectItem alloc] initWithIdentifier:identifier token:token];
        item.uploadStartTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        [self.collectItemList addObject:item];
    });
}

- (void)update:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier {
    if (!identifier || !key || ![self.updateKeysList containsObject:key]) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (currentItem) {
            [currentItem setValue:value forKey:key];
        }
    });
}

- (void)append:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier {
    if (!identifier || !key || ![self.appendKeysList containsObject:key]) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (currentItem) {
            // append NSNumber value
            NSNumber *formalValue = [currentItem valueForKey:key];
            NSNumber *appendValue = (NSNumber *)value;
            int64_t newValue = formalValue.longValue + appendValue.longValue;
            [currentItem setValue:@(newValue) forKey:key];
        }
    });
}

- (void)addRequestWithType:(QNRequestType)upType httpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo fileOffset:(int64_t)fileOffset targetRegionId:(NSString *)targetRegionId currentRegionId:(NSString *)currentRegionId identifier:(NSString *)identifier {
    
    if (!identifier || !httpResponseInfo) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (currentItem) {
            [currentItem.httpRequestList addObject:httpResponseInfo];
            if ([QNReportConfig sharedInstance].isReportEnable) {
                
                // 分块上传bytesSent字段有误差  这里分开处理
                int64_t bytesSent;
                if (upType == QNRequestType_mkblk || upType == QNRequestType_bput) {
                    if (httpResponseInfo.hasHttpResponse) {
                        bytesSent = httpResponseInfo.bytesTotal;
                    } else {
                        bytesSent = 0;
                    }
                } else {
                    bytesSent = httpResponseInfo.bytesSent;
                }
                
                QNReportRequestItem *item = [QNReportRequestItem buildWithUpType:requestTypes[upType]
                                                                    TargetBucket:currentItem.bucket
                                                                       targetKey:currentItem.key
                                                                      fileOffset:fileOffset
                                                                  targetRegionId:targetRegionId
                                                                 currentRegionId:currentRegionId
                                                               prefetchedIpCount:QN_IntNotSet
                                                                             pid:httpResponseInfo.pid
                                                                             tid:httpResponseInfo.tid
                                                                      statusCode:httpResponseInfo.statusCode
                                                                           reqId:httpResponseInfo.reqId
                                                                            host:httpResponseInfo.host
                                                                        remoteIp:httpResponseInfo.remoteIp
                                                                            port:httpResponseInfo.port totalElapsedTime:httpResponseInfo.totalElapsedTime dnsElapsedTime:httpResponseInfo.dnsElapsedTime connectElapsedTime:httpResponseInfo.connectElapsedTime tlsConnectElapsedTime:httpResponseInfo.tlsConnectElapsedTime requestElapsedTime:httpResponseInfo.requestElapsedTime waitElapsedTime:httpResponseInfo.waitElapsedTime responseElapsedTime:httpResponseInfo.responseElapsedTime bytesSent:bytesSent bytesTotal:httpResponseInfo.bytesTotal errorType:httpResponseInfo.errorType errorDescription:httpResponseInfo.errorDescription networkType:httpResponseInfo.networkType signalStrength:httpResponseInfo.signalStrength];
                [Reporter report:[item toJson] token:currentItem.token];
            }
        }
    });
}

- (QNResponseInfo *)completeWithHttpResponseInfo:(QNHttpResponseInfo *)lastHttpResponseInfo identifier:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (lastHttpResponseInfo.isOK) {
            currentItem.result = upload_ok;
        } else {
            currentItem.result = lastHttpResponseInfo.errorType;
        }
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
        info = [QNResponseInfo responseInfoWithHttpResponseInfo:lastHttpResponseInfo duration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}


- (QNResponseInfo *)completeWithInvalidArgument:(NSString *)text identifier:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        currentItem.result = invalid_args;
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
        info = [QNResponseInfo responseInfoWithInvalidArgument:text duration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}

- (QNResponseInfo *)completeWithInvalidToken:(NSString *)text identifier:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        currentItem.result = invalid_args;
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
        info = [QNResponseInfo responseInfoWithInvalidToken:text duration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}

- (QNResponseInfo *)completeWithFileError:(NSError *)error identifier:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        currentItem.result = invalid_file;
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
       info = [QNResponseInfo responseInfoWithFileError:error duration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}

- (QNResponseInfo *)completeWithLocalIOError:(NSError *)error identifier:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        currentItem.result = local_io_error;
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
       info = [QNResponseInfo responseInfoWithFileError:error duration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}

- (QNResponseInfo *)completeWithZeroData:(NSString *)path identifier:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        currentItem.result = zero_size_file;
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
        info = [QNResponseInfo responseInfoOfZeroData:path duration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}

- (QNResponseInfo *)userCancel:(NSString *)identifier {
    
    __block QNResponseInfo *info;
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        currentItem.result = user_canceled;
        currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        
        info = [QNResponseInfo cancelWithDuration:(currentItem.uploadEndTime - currentItem.uploadStartTime) / 1000.0];
        dispatch_semaphore_signal(signal);
        
        if ([QNReportConfig sharedInstance].isReportEnable) [self reportResult:currentItem];
        [self.collectItemList removeObject:currentItem];
    });
    dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    return info;
}

- (void)reportResult:(QNCollectItem *)currentItem {
    int64_t regionsCount = !currentItem.targetRegionId || !currentItem.currentRegionId || [currentItem.targetRegionId isEqualToString:currentItem.currentRegionId] ? 1 : 2;
    int64_t totalElapsedTime = currentItem.uploadEndTime - currentItem.uploadStartTime;

    if (currentItem.blockApiVersion != QN_IntNotSet) {
        QNReportBlockItem *item = [QNReportBlockItem buildWithTargetRegionId:currentItem.targetRegionId currentRegionId:currentItem.currentRegionId totalElapsedTime:totalElapsedTime bytesSent:currentItem.blockBytesSent recoveredFrom:currentItem.recoveredFrom fileSize:currentItem.fileSize pid:QN_IntNotSet tid:QN_IntNotSet upApiVersion:currentItem.blockApiVersion];
        [Reporter report:[item toJson] token:currentItem.token];
    }
    QNReportQualityItem *item = [QNReportQualityItem buildWithResult:currentItem.result totalElapsedTime:totalElapsedTime requestsCount:currentItem.httpRequestList.count regionsCount:regionsCount bytesSent:currentItem.totalBytesSent];
    [Reporter report:[item toJson] token:currentItem.token];
}

- (QNCollectItem *)getCurrentItemWithIdentifier:(NSString *)identifier {
    QNCollectItem *item = nil;
    for (NSInteger i = 0; i < self.collectItemList.count; i++) {
        QNCollectItem *currentItem = self.collectItemList[i];
        if ([currentItem.identifier isEqualToString:identifier]) {
            item = currentItem;
            break;
        }
    }
    return item;
}

@end
