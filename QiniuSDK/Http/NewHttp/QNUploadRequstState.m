//
//  QNUploadRequstState.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadRequstState.h"

@implementation QNUploadRequstState

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _isUserCancel = NO;
}

@end
