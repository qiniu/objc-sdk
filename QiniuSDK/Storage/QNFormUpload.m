//
//  QNFormUpload.m
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNFormUpload.h"
#import "QNResponseInfo.h"
#import "QNRequestTransaction.h"

@interface QNFormUpload ()

@property (nonatomic) float previousPercent;

@property(nonatomic, strong)QNRequestTransaction *uploadTransaction;

@end

@implementation QNFormUpload

- (void)startToUpload {
    
    self.uploadTransaction = [[QNRequestTransaction alloc] initWithConfig:self.config
                                                             uploadOption:self.option
                                                             targetRegion:[self getTargetRegion]
                                                            currentRegion:[self getCurrentRegion]
                                                                      key:self.key
                                                                    token:self.token];

    __weak typeof(self) weakSelf = self;
    void(^progressHandler)(long long totalBytesWritten, long long totalBytesExpectedToWrite) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        if (weakSelf.option.progressHandler) {
            float percent = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
            if (percent > 0.95) {
                percent = 0.95;
            }
            if (percent > self.previousPercent) {
                self.previousPercent = percent;
            } else {
                percent = self.previousPercent;
            }
            QNAsyncRunInMain(^{
                weakSelf.option.progressHandler(weakSelf.key, percent);
            });
        }
    };
 
    [self.uploadTransaction uploadFormData:self.data
                                  fileName:self.fileName
                                  progress:progressHandler
                                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        if (responseInfo.isOK) {
            QNAsyncRunInMain(^{
                self.option.progressHandler(self.key, 1.0);
            });
            [self complete:responseInfo response:response];
        } else if (responseInfo.couldRetry && self.config.allowBackupHost) {
            BOOL isSwitched = [self switchRegionAndUpload];
            if (isSwitched == NO) {
                [self complete:responseInfo response:response];
            }
        } else {
            [self complete:responseInfo response:response];
        }
    }];
}

@end
