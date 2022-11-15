//
//  QNFormUpload.m
//  QiniuSDK
//
//  Created by bailong on 15/1/4.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//
#import "QNDefine.h"
#import "QNLogUtil.h"
#import "QNFormUpload.h"
#import "QNResponseInfo.h"
#import "QNUpProgress.h"
#import "QNRequestTransaction.h"

@interface QNFormUpload ()

@property(nonatomic, strong)QNUpProgress *progress;

@property(nonatomic, strong)QNRequestTransaction *uploadTransaction;

@end

@implementation QNFormUpload

- (void)startToUpload {
    [super startToUpload];
    
    QNLogInfo(@"key:%@ form上传", self.key);
    
    self.uploadTransaction = [[QNRequestTransaction alloc] initWithConfig:self.config
                                                             uploadOption:self.option
                                                             targetRegion:[self getTargetRegion]
                                                            currentRegion:[self getCurrentRegion]
                                                                      key:self.key
                                                                    token:self.token];

    kQNWeakSelf;
    void(^progressHandler)(long long totalBytesWritten, long long totalBytesExpectedToWrite) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kQNStrongSelf;
        [self.progress progress:self.key uploadBytes:totalBytesWritten totalBytes:totalBytesExpectedToWrite];
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
        
        [self.progress notifyDone:self.key totalBytes:self.data.length];
        [self complete:responseInfo response:response];
    }];
}

- (QNUpProgress *)progress {
    if (_progress == nil) {
        _progress = [QNUpProgress progress:self.option.progressHandler byteProgress:self.option.byteProgressHandler];
    }
    return _progress;
}

- (NSArray *)needApis {
    return @[@"up.formupload"];
}

- (NSString *)upType {
    return QNUploadUpTypeForm;
}
@end
