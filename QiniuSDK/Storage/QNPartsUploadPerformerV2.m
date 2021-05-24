//
//  QNPartsUploadApiV2.m
//  QiniuSDK
//
//  Created by yangsen on 2020/11/30.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNLogUtil.h"
#import "QNDefine.h"
#import "QNRequestTransaction.h"
#import "QNUploadInfoV2.h"
#import "QNPartsUploadPerformerV2.h"

@interface QNPartsUploadPerformerV2()
@end
@implementation QNPartsUploadPerformerV2

- (QNUploadInfo *)getFileInfoWithDictionary:(NSDictionary *)fileInfoDictionary {
    return [QNUploadInfoV2 info:self.uploadSource dictionary:fileInfoDictionary];
}

- (QNUploadInfo *)getDefaultUploadInfo {
    return [QNUploadInfoV2 info:self.uploadSource configuration:self.config];
}

- (void)serverInit:(void(^)(QNResponseInfo * _Nullable responseInfo,
                            QNUploadRegionRequestMetrics * _Nullable metrics,
                            NSDictionary * _Nullable response))completeHandler {
    
    QNUploadInfoV2 *uploadInfo = (QNUploadInfoV2 *)self.uploadInfo;
    if (uploadInfo && [uploadInfo isValid]) {
        QNLogInfo(@"key:%@ serverInit success", self.key);
        QNResponseInfo *responseInfo = [QNResponseInfo successResponse];
        completeHandler(responseInfo, nil, nil);
        return;
    }
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];

    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction initPart:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
                
        NSString *uploadId = response[@"uploadId"];
        NSNumber *expireAt = response[@"expireAt"];
        if (responseInfo.isOK && uploadId && expireAt) {
            uploadInfo.uploadId = uploadId;
            uploadInfo.expireAt = expireAt;
            [self recordUploadInfo];
        }
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}

- (void)uploadNextData:(void(^)(BOOL stop,
                                QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    QNUploadInfoV2 *uploadInfo = (QNUploadInfoV2 *)self.uploadInfo;
    
    NSError *error = nil;
    QNUploadData *data = nil;
    @synchronized (self) {
        data = [uploadInfo nextUploadData:&error];
        data.state = QNUploadStateUploading;
    }
    
    if (error) {
        QNResponseInfo *responseInfo = [QNResponseInfo responseInfoWithLocalIOError:[NSString stringWithFormat:@"%@", error]];
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    // 上传完毕
    if (data == nil) {
        QNLogInfo(@"key:%@ no data left", self.key);
        
        QNResponseInfo *responseInfo = nil;
        if (uploadInfo.getSourceSize == 0) {
            responseInfo = [QNResponseInfo responseInfoOfZeroData:@"file is empty"];
        } else {
            responseInfo = [QNResponseInfo responseInfoWithSDKInteriorError:@"no chunk left"];
        }
        completeHandler(YES, responseInfo, nil, nil);
        return;
    }
    
    kQNWeakSelf;
    void (^progress)(long long, long long) = ^(long long totalBytesWritten, long long totalBytesExpectedToWrite){
        kQNStrongSelf;
        data.uploadSize = totalBytesWritten;
        [self notifyProgress:false];
    };
    
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kQNWeakObj(transaction);
    [transaction uploadPart:uploadInfo.uploadId
                  partIndex:[uploadInfo getPartIndexOfData:data]
                   partData:data.data
                   progress:progress
                   complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);

        NSString *etag = response[@"etag"];
        NSString *md5 = response[@"md5"];
        if (responseInfo.isOK && etag && md5) {
            data.etag = etag;
            data.state = QNUploadStateComplete;
            [self recordUploadInfo];
            [self notifyProgress:false];
        } else {
            data.state = QNUploadStateWaitToUpload;
        }
        completeHandler(NO, responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}

- (void)completeUpload:(void(^)(QNResponseInfo * _Nullable responseInfo,
                                QNUploadRegionRequestMetrics * _Nullable metrics,
                                NSDictionary * _Nullable response))completeHandler {
    
    QNUploadInfoV2 *uploadInfo = (QNUploadInfoV2 *)self.uploadInfo;
    
    NSArray *partInfoArray = [uploadInfo getPartInfoArray];
    QNRequestTransaction *transaction = [self createUploadRequestTransaction];
    
    kQNWeakSelf;
    kQNWeakObj(transaction);
    [transaction completeParts:self.fileName uploadId:uploadInfo.uploadId partInfoArray:partInfoArray complete:^(QNResponseInfo * _Nullable responseInfo, QNUploadRegionRequestMetrics * _Nullable metrics, NSDictionary * _Nullable response) {
        kQNStrongSelf;
        kQNStrongObj(transaction);
        if (responseInfo.isOK) {
            [self notifyProgress:true];
        }
        completeHandler(responseInfo, metrics, response);
        [self destroyUploadRequestTransaction:transaction];
    }];
}


@end
