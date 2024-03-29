//
//  QNUpProgress.m
//  QiniuSDK
//
//  Created by yangsen on 2021/5/21.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import "QNUpProgress.h"

@interface QNUpProgress()

@property(nonatomic, assign)long long maxProgressUploadBytes;
@property(nonatomic, assign)long long previousUploadBytes;
@property(nonatomic,  copy)QNUpProgressHandler progress;
@property(nonatomic,  copy)QNUpByteProgressHandler byteProgress;

@end
@implementation QNUpProgress

+ (instancetype)progress:(QNUpProgressHandler)progress byteProgress:(QNUpByteProgressHandler)byteProgress {
    QNUpProgress *upProgress = [[QNUpProgress alloc] init];
    upProgress.maxProgressUploadBytes = -1;
    upProgress.previousUploadBytes = 0;
    upProgress.progress = progress;
    upProgress.byteProgress = byteProgress;
    return upProgress;
}

- (void)progress:(NSString *)key uploadBytes:(long long)uploadBytes totalBytes:(long long)totalBytes {
    if ((self.progress == nil && self.byteProgress == nil) || uploadBytes < 0 || (totalBytes > 0 && uploadBytes > totalBytes)) {
        return;
    }
    
    if (totalBytes > 0) {
        @synchronized (self) {
            if (self.maxProgressUploadBytes < 0) {
                self.maxProgressUploadBytes = totalBytes * 0.95;
            }
        }
        
        if (uploadBytes > self.maxProgressUploadBytes) {
            return;
        }
    }
    
    @synchronized (self) {
        if (uploadBytes > self.previousUploadBytes) {
            self.previousUploadBytes = uploadBytes;
        } else {
            return;
        }
    }
    
    [self notify:key uploadBytes:uploadBytes totalBytes:totalBytes];
}

- (void)notifyDone:(NSString *)key totalBytes:(long long)totalBytes {
    [self notify:key uploadBytes:totalBytes totalBytes:totalBytes];
}

- (void)notify:(NSString *)key uploadBytes:(long long)uploadBytes totalBytes:(long long)totalBytes {
    if (self.progress == nil && self.byteProgress == nil) {
        return;
    }
    
    if (self.byteProgress) {
        QNAsyncRunInMain(^{
            self.byteProgress(key, uploadBytes, totalBytes);
        });
        return;
    }
    
    if (totalBytes <= 0) {
        return;
    }
    
    if (self.progress) {
        QNAsyncRunInMain(^{
            double notifyPercent = (double) uploadBytes / (double) totalBytes;
            self.progress(key, notifyPercent);
        });
    }
}

@end
