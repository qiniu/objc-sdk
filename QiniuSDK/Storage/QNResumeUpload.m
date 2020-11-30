//
//  QNResumeUpload.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/6.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNDefine.h"
#import "QNResumeUpload.h"
#import "QNResponseInfo.h"
#import "QNRequestTransaction.h"

@interface QNResumeUpload ()

@property (nonatomic, assign) float previousPercent;
@property(nonatomic, strong)QNRequestTransaction *uploadTransaction;

@property(nonatomic, strong)QNResponseInfo *uploadDataErrorResponseInfo;
@property(nonatomic, strong)NSDictionary *uploadDataErrorResponse;

@end

@implementation QNResumeUpload

- (void)startToUpload{
    [super startToUpload];
    
    self.previousPercent = 0;
    self.uploadDataErrorResponseInfo = nil;
    self.uploadDataErrorResponse = nil;
    

    kQNWeakSelf;
    // 1. 启动upload
    [self initPartToServer:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        if (!responseInfo.isOK || !self.uploadFileInfo.uploadId || self.uploadFileInfo.uploadId.length == 0) {
            [self complete:responseInfo response:response];
            return;
        }
        
        // 2. 上传数据
        [self uploadRestData:^{
            if (![self.uploadFileInfo isAllUploaded]) {
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

                if (responseInfo.isOK == NO) {
                    if (responseInfo.couldRetry && [self.config allowBackupHost]) {
                        BOOL isSwitched = [self switchRegionAndUpload];
                        if (isSwitched == NO) {
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

- (void)uploadRestData:(dispatch_block_t)completeHandler{
    if (!self.uploadFileInfo) {
        [self setErrorResponseInfo:[QNResponseInfo responseInfoWithInvalidArgument:@"file error"] errorResponse:nil];
        completeHandler();
        return;
    }
    
    id <QNUploadRegion> currentRegion = [self getCurrentRegion];
    if (!currentRegion) {
        [self setErrorResponseInfo:[QNResponseInfo responseInfoWithNoUsableHostError:@"server error"] errorResponse:nil];
        completeHandler();
        return;
    }
    
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
    self.uploadTransaction = transaction;
    return transaction;
}


@end
