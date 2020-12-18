//
//  QNFormUpload.m
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//
#import "QNDefine.h"
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

    kQNWeakSelf;
    void(^progressHandler)(long long totalBytesWritten, long long totalBytesExpectedToWrite) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kQNStrongSelf;
        
        if (self.option.progressHandler) {
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
                self.option.progressHandler(self.key, percent);
            });
        }
    };
 
    [self.uploadTransaction uploadFormData:self.data
                                  fileName:self.fileName
                                  progress:progressHandler
                                  complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        
        [self addRegionRequestMetricsOfOneFlow:metrics];
        
        if (!responseInfo.isOK) {
            if (![self switchRegionAndUploadIfNeededWithErrorResponse:responseInfo]) {
                [self complete:responseInfo response:response];
            }
            return;
        }
        
        QNAsyncRunInMain(^{
            self.option.progressHandler(self.key, 1.0);
        });
        [self complete:responseInfo response:response];
    }];
}

@end
