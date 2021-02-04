//
//  QNUploadRequestState.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNIUploadServer.h"
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
    _httpVersion = kQNHttpVersion2;
    _isUseOldServer = NO;
}

- (instancetype)copy {
    QNUploadRequestState *state = [[QNUploadRequestState alloc] init];
    state.httpVersion = self.httpVersion;
    state.isUserCancel = self.isUserCancel;
    state.isUseOldServer = self.isUseOldServer;
    return state;
}

- (BOOL)isHTTP3 {
    return [self.httpVersion isEqualToString:kQNHttpVersion3];
}

@end
