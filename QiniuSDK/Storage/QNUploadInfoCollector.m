//
//  QNUploadInfoCollector.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/15.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadInfoCollector.h"

QNCollectKey *const CK_targetRegionId = @"targetRegionId";
QNCollectKey *const CK_currentRegionId = @"currentRegionId";
QNCollectKey *const CK_result = @"result";
QNCollectKey *const CK_cloudType = @"cloudType";
QNCollectKey *const CK_blockBytesSent = @"blockBytesSent";
QNCollectKey *const CK_recoveredFrom = @"recoveredFrom";
QNCollectKey *const CK_totalBytesSent = @"totalBytesSent";
QNCollectKey *const CK_fileSize = @"fileSize";
QNCollectKey *const CK_blockApiVersion = @"blockApiVersion";
QNCollectKey *const CK_requestItem = @"requestItem";

@interface QNCollectItem : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *targetRegionId;
@property (nonatomic, copy) NSString *currentRegionId;
@property (nonatomic, copy) NSString *result;
@property (nonatomic, copy) NSString *cloudType;

@property (nonatomic, assign) uint64_t uploadStartTime;
@property (nonatomic, assign) uint64_t uploadEndTime;
@property (nonatomic, assign) uint64_t totalBytesSent;
@property (nonatomic, assign) uint64_t fileSize;

@property (nonatomic, assign) uint64_t recoveredFrom;
@property (nonatomic, assign) uint64_t blockApiVersion;
@property (nonatomic, assign) uint64_t blockBytesSent;

@property (nonatomic, strong) NSMutableArray<QNReportRequestItem *> *requestList;
@end

@implementation QNCollectItem

- (instancetype)initWithIdentifier:(NSString *)identifier token:(NSString *)token
{
    self = [super init];
    if (self) {
        _identifier = identifier;
        _token = token;
        _requestList = [NSMutableArray array];
    }
    return self;
}

@end

@interface QNUploadInfoCollector ()
@property (nonatomic, strong) NSArray<QNCollectKey *> *updateKeysList;
@property (nonatomic, strong) NSArray <QNCollectKey *>*appendKeysList;
@property (nonatomic, strong) NSMutableArray<QNCollectItem *> *collectItemList;
//@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) dispatch_queue_t collectQueue;
@end

@implementation QNUploadInfoCollector
+ (instancetype)sharedInstance {
    
    static QNUploadInfoCollector *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.collectItemList = [NSMutableArray array];
//        sharedInstance.lock = [[NSLock alloc] init];
        sharedInstance.collectQueue = dispatch_queue_create("com.qiniu.collector", DISPATCH_QUEUE_SERIAL);
        sharedInstance.updateKeysList = @[
            CK_targetRegionId,
            CK_currentRegionId,
            CK_result,
            CK_cloudType,
            CK_recoveredFrom,
            CK_fileSize,
            CK_blockApiVersion];
        sharedInstance.appendKeysList = @[
            CK_blockBytesSent,
            CK_totalBytesSent,
            CK_requestItem];
    });
    return sharedInstance;
}

- (void)registerWithIdentifier:(NSString *)identifier token:(NSString *)token {
    if (!identifier || !token || ![QNReportConfig sharedInstance].isReportEnable) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *item = [[QNCollectItem alloc] initWithIdentifier:identifier token:token];
        item.uploadStartTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        [self.collectItemList addObject:item];
    });
}

- (void)update:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier {
    if (!identifier || !key || ![self.updateKeysList containsObject:key] || ![QNReportConfig sharedInstance].isReportEnable) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (currentItem) {
            [currentItem setValue:value forKey:key];
        }
    });
}

- (void)append:(QNCollectKey *)key value:(id)value identifier:(NSString *)identifier {
    if (!identifier || !key || ![self.appendKeysList containsObject:key] || ![QNReportConfig sharedInstance].isReportEnable) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (currentItem) {
            if ([key isEqualToString:CK_requestItem]) {
                // request item report
                QNReportRequestItem *item = (QNReportRequestItem *)value;
                [currentItem.requestList addObject:item];
                [UploadInfoReporter report:[item toJson] token:currentItem.token];
            } else {
                // append NSNumber value
                NSNumber *formalValue = [currentItem valueForKey:key];
                NSNumber *appendValue = (NSNumber *)value;
                uint64_t newValue = formalValue.longValue + appendValue.longValue;
                [currentItem setValue:@(newValue) forKey:key];
            }
        }
    });
}

- (void)resignWithIdentifier:(NSString *)identifier result:(NSString *)result {
    if (!identifier || !result || ![QNReportConfig sharedInstance].isReportEnable) return;
    dispatch_async(_collectQueue, ^{
        QNCollectItem *currentItem = [self getCurrentItemWithIdentifier:identifier];
        if (currentItem) {
            currentItem.result = result;
            currentItem.uploadEndTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
            [self report:currentItem];
            [self.collectItemList removeObject:currentItem];
        }
    });
}

- (void)report:(QNCollectItem *)currentItem {
    uint64_t regionsCount = [currentItem.targetRegionId isEqualToString:currentItem.currentRegionId] ? 1 : 2;
    uint64_t totalElapsedTime = currentItem.uploadEndTime - currentItem.uploadStartTime;

    if (currentItem.blockApiVersion != 0) {
        QNReportBlockItem *item = [QNReportBlockItem buildWithTargetRegionId:currentItem.targetRegionId currentRegionId:currentItem.currentRegionId totalElapsedTime:totalElapsedTime bytesSent:currentItem.blockBytesSent recoveredFrom:currentItem.recoveredFrom fileSize:currentItem.fileSize pid:0 tid:0 upApiVersion:currentItem.blockApiVersion];
        [UploadInfoReporter report:[item toJson] token:currentItem.token];
    }
    QNReportQualityItem *item = [QNReportQualityItem buildWithResult:currentItem.result totalElapsedTime:totalElapsedTime requestsCount:currentItem.requestList.count regionsCount:regionsCount bytesSent:currentItem.totalBytesSent cloudType:currentItem.cloudType];
    [UploadInfoReporter report:[item toJson] token:currentItem.token];
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
