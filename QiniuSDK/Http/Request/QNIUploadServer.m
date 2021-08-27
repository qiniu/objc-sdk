//
//  QNIUploadServer.m
//  QiniuSDK
//
//  Created by yangsen on 2021/2/4.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import "QNIUploadServer.h"

BOOL kQNIsHttp3(NSString * _Nullable httpVersion) {
    return [httpVersion isEqualToString:kQNHttpVersion3];
}

BOOL kQNIsHttp2(NSString * _Nullable httpVersion) {
    return [httpVersion isEqualToString:kQNHttpVersion2];
}
