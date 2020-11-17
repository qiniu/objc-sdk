//
//  QNUploadRequestState.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequestState.h"

@implementation QNUploadRequestState
- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}
- (void)initData{
    _isUserCancel = NO;
    _isHTTP3 = NO;
    _isUseOldServer = NO;
}
@end
