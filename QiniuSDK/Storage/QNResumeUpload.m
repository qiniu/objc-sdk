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
@end

@implementation QNResumeUpload

- (void)startToUpload{
    [super startToUpload];

    kQNWeakSelf;
    // 1. 启动upload
    [self serverInit:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        if (!responseInfo.isOK) {
            [self complete:responseInfo response:response];
            return;
        }
        
        // 2. 上传数据
        [self uploadRestData:^{
            if (![self isAllUploaded]) {
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
            [self completeUpload:^(QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {

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
                    [self complete:responseInfo response:response];
                }
            }];
        }];
    }];
}

- (void)uploadRestData:(dispatch_block_t)completeHandler{

    [self uploadNextDataCompleteHandler:^(BOOL stop, QNResponseInfo * _Nullable responseInfo, NSDictionary * _Nullable response) {
        if (stop || !responseInfo.isOK) {
            [self setErrorResponseInfo:responseInfo errorResponse:response];
            completeHandler();
        } else {
            [self uploadRestData:completeHandler];
        }
    }];
}

@end
