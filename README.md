# Qiniu Objective-C SDK
[![Software License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.md)
[![Build Status](https://travis-ci.org/qiniu/objc-sdk.svg?branch=master)](https://travis-ci.org/qiniu/objc-sdk)
[![Latest Stable Version](https://badge.fury.io/co/Qiniu.png)](https://github.com/qiniu/objc-sdk/releases)

## 安装

通过CocoaPods

```ruby
pod "Qiniu", "~> 7.0"
```

## 运行环境

| Qiniu SDK版本 | 最低 iOS版本   | 最低 OS X 版本  |                                   Notes                                   |
|:--------------------:|:---------------------------:|:----------------------------:|:-------------------------------------------------------------------------:|
|          7.x         |            iOS 6            |           OS X 10.8          | Xcode最低版本 5.  |
|          [6.x](https://github.com/qiniu/ios-sdk)         |            iOS 6            |         None        |Xcode最低版本 5. |


## 使用方法

```objective-c
#import <QiniuSDK.h>
...
    NSString token = @"从服务端SDK获取";
    QNUploadManager *upManager = [[QNUploadManager alloc] init];
    NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
    [upManager putData:data key:@"hello" token:token
        complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"%@", info);
        NSLog(@"%@", resp);
    } option:nil];
...
```


## 测试

``` bash
$ xctool -workspace QiniuSDK.xcworkspace -scheme "QiniuSDK Mac" -sdk macosx -configuration Release test -test-sdk macosx
```


## 代码贡献

详情参考[代码提交指南](https://github.com/qiniu/objc-sdk/blob/master/CONTRIBUTING.md)。

## 贡献记录

- [所有贡献者](https://github.com/qiniu/objc-sdk/contributors)


## 代码许可

The MIT License (MIT).详情见 [License文件](https://github.com/qiniu/objc-sdk/blob/master/LICENSE).
