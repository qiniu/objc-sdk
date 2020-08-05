//
//  QNUploadRequestInfo.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/5/13.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestInfo.h"

@implementation QNUploadRequestInfo

- (BOOL)shouldReportRequestLog{
    return ![self.requestType isEqualToString:QNUploadRequestTypeUpLog];
}

@end

NSString * const QNUploadRequestTypeUCQuery = @"uc_query";
NSString * const QNUploadRequestTypeForm = @"form";
NSString * const QNUploadRequestTypeMkblk = @"mkblk";
NSString * const QNUploadRequestTypeBput = @"bput";
NSString * const QNUploadRequestTypeMkfile = @"mkfile";
NSString * const QNUploadRequestTypeUpLog = @"uplog";
