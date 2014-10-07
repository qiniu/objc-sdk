# Qiniu Objective-C SDK

[![Build Status](https://travis-ci.org/qiniu/objective-c-sdk.svg?branch=master)](https://travis-ci.org/qiniu/objective-c-sdk)
[![Latest Stable Version](https://badge.fury.io/co/Qiniu.png)](https://github.com/qiniu/objective-c-sdk/releases)

## 安装

通过CocoaPods

``` ruby
platform :ios, '6.0'
pod "Qiniu", "~> 7.0"
```


## 使用方法

先通过服务器端sdk生成token
``` objective-c
NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
[self.upManager putData:data key:@"hello" token:token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
    testInfo = info;
    testResp = resp;
} option:nil];

```


## 测试

``` bash
$ xctool -workspace QiniuSDK.xcworkspace -scheme "QiniuSDK Mac" -sdk macosx -configuration Release test -test-sdk macosx
```


## 代码贡献

详情参考[代码提交指南](https://github.com/qiniu/objective-c-sdk/blob/master/CONTRIBUTING.md)。

## 贡献记录

- [qiniu](https://github.com/qiniusdk)
- [所有贡献者](https://github.com/qiniu/objective-c-sdk/contributors)


## License

The MIT License (MIT). Please see [License File](https://github.com/qiniu/objective-c-sdk/blob/master/LICENSE) for more information.
