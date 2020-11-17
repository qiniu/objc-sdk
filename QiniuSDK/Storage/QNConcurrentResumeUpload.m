//
//  QNConcurrentResumeUpload.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/7/15.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import "QNConcurrentResumeUpload.h"
#import "QNResponseInfo.h"
#import "QNAsyncRun.h"
#import "QNRequestTransaction.h"
#import "QNDefine.h"

@interface QNConcurrentResumeUpload()

@property(nonatomic, strong) dispatch_group_t uploadGroup;
@property(nonatomic, strong) dispatch_queue_t uploadQueue;

@property(nonatomic, assign) float previousPercent;
@property(nonatomic, strong)NSMutableArray <QNRequestTransaction *> *uploadTransactions;

@property(nonatomic, strong)QNResponseInfo *uploadDataErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadDataErrorResponse;

@end

@implementation QNConcurrentResumeUpload

- (int)prepareToUpload{
    self.uploadGroup = dispatch_group_create();
    self.uploadQueue = dispatch_queue_create("com.qiniu.concurrentUpload", DISPATCH_QUEUE_SERIAL);
    return [super prepareToUpload];
}

- (void)startToUpload{
    [super startToUpload];
    
    self.previousPercent = 0;
    self.uploadDataErrorResponseInfo = nil;
    self.uploadDataErrorResponse = nil;
    self.uploadTransactions = [NSMutableArray array];
    
    NSLog(@"concurrent resume task count: %u", (unsigned int)self.config.concurrentTaskCount);
    
    kQNWeakSelf;
    // 1. 启动upload
    [self initPartToServer:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        if (!responseInfo.isOK || !self.uploadFileInfo.uploadId || self.uploadFileInfo.uploadId.length == 0) {
            [self complete:responseInfo response:response];
            return;
        }
        
        // 2. 上传数据
        [self concurrentUploadRestData:^{
            if ([self.uploadFileInfo isAllUploaded] == NO || self.uploadDataErrorResponseInfo) {
                if (self.uploadDataErrorResponseInfo.couldRetry && [self.config allowBackupHost]) {
                    BOOL isSwitched = [self switchRegionAndUpload];
                    if (isSwitched == NO) {
                        [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                    }
                } else {
                    [self complete:self.uploadDataErrorResponseInfo response:self.uploadDataErrorResponse];
                }
                return;
            }
            
            // 3. 组装文件
            [self completePartsToServer:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
                if (!responseInfo.isOK) {
                    if (responseInfo.couldRetry && [self.config allowBackupHost]) {
                        if (![self switchRegionAndUpload]) {
                            [self complete:responseInfo response:response];
                        }
                    } else {
                        [self complete:responseInfo response:response];
                    }
                } else {
                    QNAsyncRunInMain(^{
                        self.option.progressHandler(self.key, 1.0);
                    });
                    [self removeUploadInfoRecord];
                    [self complete:responseInfo response:response];
                }
            }];
        }];
    }];
}

- (void)concurrentUploadRestData:(dispatch_block_t)completeHandler{
    for (int i = 0; i < self.config.concurrentTaskCount; i++) {
        dispatch_group_enter(_uploadGroup);
        dispatch_group_async(_uploadGroup, _uploadQueue, ^{
            [self uploadRestData:^{
                dispatch_group_leave(self.uploadGroup);
            }];
        });
    }
    dispatch_group_notify(_uploadGroup, _uploadQueue, ^{
        completeHandler();
    });
}

- (void)uploadRestData:(dispatch_block_t)completeHandler{
    if (!self.uploadFileInfo) {
        [self setErrorResponseInfo:[QNResponseInfo responseInfoWithInvalidArgument:@"file error"] errorResponse:nil];
        completeHandler();
        return;
    }
    
    id <QNUploadRegion> currentRegion = [self getCurrentRegion];
    if (!currentRegion) {
        [self setErrorResponseInfo:[QNResponseInfo responseInfoWithNoUsableHostError:@"regions server error"] errorResponse:nil];
        completeHandler();
        return;
    }
    
    @synchronized (self) {
        QNUploadData *data = [self.uploadFileInfo nextUploadData];
        
        kQNWeakSelf;
        void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
            kQNStrongSelf;
            
            data.progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
            
            float percent = self.uploadFileInfo.progress;
            if (percent > 0.95) {
                percent = 0.95;
            }
            if (percent > self.previousPercent) {
                self.previousPercent = percent;
            } else {
                percent = self.previousPercent;
            }
            QNAsyncRunInMain(^{
                self.option.progressHandler(self.key, percent);
            });
        };
        
        if (!data) {
            completeHandler();
        } else {
            [self uploadDataToServer:data progress:progress completeHandler:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
                if (!responseInfo.isOK) {
                    self.uploadDataErrorResponseInfo = responseInfo;
                    self.uploadDataErrorResponse = response;
                    completeHandler();
                } else {
                    [self uploadRestData:completeHandler];
                }
            }];
        }
    }
}

- (void)setErrorResponseInfo:(QNResponseInfo *)responseInfo errorResponse:(NSDictionary *)response{
    if (!self.uploadDataErrorResponseInfo
        || (responseInfo.statusCode == kQNNoUsableHostError)) {
        self.uploadDataErrorResponseInfo = responseInfo;
        self.uploadDataErrorResponse = response ?: responseInfo.responseDictionary;
    }
}

- (QNRequestTransaction *)createUploadRequestTransaction{
    QNRequestTransaction *transaction = [[QNRequestTransaction alloc] initWithConfig:self.config
                                                                        uploadOption:self.option
                                                                        targetRegion:[self getTargetRegion]
                                                                       currentRegion:[self getCurrentRegion]
                                                                                 key:self.key
                                                                               token:self.token];
    [self.uploadTransactions addObject:transaction];
    return transaction;
}
- (void)removeUploadRequestTransaction:(QNRequestTransaction *)transaction{
    [self.uploadTransactions removeObject:transaction];
}

- (void)destroyUploadRequestTransaction:(QNRequestTransaction *)transaction{
    if (transaction) {
        [self.uploadTransactions removeObject:transaction];
    }
}

@end
