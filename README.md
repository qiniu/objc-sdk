# Qiniu Resource Storage SDK for Objective-C

[![@qiniu on weibo](http://img.shields.io/badge/weibo-%40qiniutek-blue.svg)](http://weibo.com/qiniutek)
[![Software License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.md)
[![Build Status](https://github.com/qiniu/objc-sdk/workflows/Run%20Test%20Cases/badge.svg)](https://github.com/qiniu/objc-sdk/actions)
[![Badge w/ Version](https://cocoapod-badges.herokuapp.com/v/Qiniu/badge.png)](http://cocoadocs.org/docsets/Qiniu)
[![GitHub release](https://img.shields.io/github/v/tag/qiniu/objc-sdk.svg?label=release)](https://github.com/qiniu/objc-sdk/releases)
[![codecov](https://codecov.io/gh/qiniu/objc-sdk/branch/master/graph/badge.svg)](https://codecov.io/gh/qiniu/objc-sdk)
![Platform](http://img.shields.io/cocoapods/p/Qiniu.svg)


## 安装

通过 CocoaPods

```ruby
pod "Qiniu", "~> 8.8.0" 
```

通过 Swift Package Manager (Xcode 11+)
```
App 对接:
File -> Swift Packages -> Add Package Dependency，输入库链接，选择相应版本即可
库链接: https://github.com/qiniu/objc-sdk

库对接:
let package = Package(
    dependencies: [
        .package(url: "https://github.com/qiniu/objc-sdk", from: "8.8.0")
    ],
    // ...
)

```

## 运行环境

|               Qiniu SDK 版本               | 最低 iOS版本 | 最低 OS X 版本 |     Notes     |
| :--------------------------------------: | :------: | :--------: | :-----------: |
|                  8.8.x                   |  iOS 9   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.7.x                   |  iOS 9   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.6.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.5.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.4.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.3.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.2.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.1.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  8.0.x                   |  iOS 7   | OS X 10.15  | Xcode 最低版本 11 |
|                  7.5.x                   |  iOS 7   | OS X 10.9  | Xcode 最低版本 6. |
|                  7.4.x                   |  iOS 7   | OS X 10.9  | Xcode 最低版本 6. |
|                  7.3.x                   |  iOS 7   | OS X 10.9  | Xcode 最低版本 6. |
|                  7.2.x                   |  iOS 7   | OS X 10.9  | Xcode 最低版本 6. |
|         7.1.x / AFNetworking-3.x         |  iOS 7   | OS X 10.9  | Xcode 最低版本 6. |
| [7.0.x / AFNetworking-2.x](https://github.com/qiniu/objc-sdk/tree/7.0.x/AFNetworking-2.x) |  iOS 6   | OS X 10.8  | Xcode 最低版本 5. |
| [7.x / AFNetworking-1.x](https://github.com/qiniu/objc-sdk/tree/AFNetworking-1.x) |  iOS 5   | OS X 10.7  | Xcode 最低版本 5. |
| [6.x](https://github.com/qiniu/ios-sdk)  |  iOS 6   |    None    | Xcode 最低版本 5. |

## 使用方法

### 简单上传
```Objective-C
#import <QiniuSDK.h>
...
    NSString *token = @"从服务端SDK获取";
    QNUploadManager *upManager = [[QNUploadManager alloc] init];
    NSData *data = [@"Hello, World!" dataUsingEncoding : NSUTF8StringEncoding];
    [upManager putData:data key:@"hello" token:token
        complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"%@", info);
        NSLog(@"%@", resp);
    } option:[QNUploadOption defaultOptions]];
...
```

### 如使用最新版的sdk，默认自动判断上传空间。如需要指定上传区域，可以按如下方式上传：
```Objective-C
#import <QiniuSDK.h>
...
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useHttps = YES;// 是否使用https
        builder.zone = [[QNAutoZone alloc] init];// 根据 bucket 自动查询区域
        // builder.zone = [QNFixedZone createWithRegionId:@"z0"];// 指定华东区域
        // builder.zone = [QNFixedZone createWithRegionId:@"z1"];// 指定华北区域
        // builder.zone = [QNFixedZone createWithRegionId:@"z2"];// 指定华南区域
        // builder.zone = [QNFixedZone createWithRegionId:@"na0"];// 指定北美区域
        // builder.zone = [QNFixedZone createWithRegionId:@"as0"];// 指定东南亚区域
    }];
    
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:config];
    QNUploadOption *option = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    
    NSData *data = [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *token = @"从服务端SDK获取";
    [upManager putData:data key:@"hello" token:token complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"%@", info);
        NSLog(@"%@", resp);
    } option:option];
...
```

建议 QNUploadManager 创建一次重复使用, 或者使用单例方式创建.

## 测试

### 所有测试

``` bash
$ xcodebuild test -workspace QiniuSDK.xcworkspace -scheme QiniuSDK_Mac -configuration Release -destination 'platform=macOS,arch=x86_64'
```
### 指定测试

可以在单元测试上修改, 熟悉 SDK

``` bash
$ xcodebuild test -workspace QiniuSDK.xcworkspace -scheme QiniuSDK_Mac -configuration Release -destination 'platform=macOS,arch=x86_64' -only-testing:"QiniuSDK_MacTests/QNResumeUploadTest/test5M"
```

## 示例代码
* 完整的demo 见 QiniuDemo 目录下的代码
* 具体细节的一些配置 可参考 QiniuSDKTests 下面的一些单元测试，以及源代码

## 常见问题

- 如果碰到 crc 链接错误, 请把 libz.dylib 加入到项目中去
- 如果碰到 res_9_ninit 链接错误, 请把 libresolv.dylib 加入到项目中去
- 如果需要支持 iOS 5 或者支持 RestKit, 请用 AFNetworking 1.x 分支的版本
- 如果碰到其他编译错误, 请参考 CocoaPods 的 [troubleshooting](http://guides.cocoapods.org/using/troubleshooting.html)
- iOS 9+ 强制使用https，需要在project build info 添加NSAppTransportSecurity类型Dictionary。在NSAppTransportSecurity下添加NSAllowsArbitraryLoads类型Boolean,值设为YES。 具体操作可参见 http://blog.csdn.net/guoer9973/article/details/48622823
- 上传返回错误码理解，[status code 注释](https://github.com/qiniu/objc-sdk/blob/master/QiniuSDK/Common/QNErrorCode.h)

## 代码贡献

详情参考 [代码提交指南](https://github.com/qiniu/objc-sdk/blob/master/Contributing.md).

## 贡献记录

- [所有贡献者](https://github.com/qiniu/objc-sdk/contributors)

## 联系我们

- 如果需要帮助, 请提交工单 (在 portal 右侧点击咨询和建议提交工单, 或者直接向 support@qiniu.com 发送邮件)
- 如果有什么问题, 可以到问答社区提问, [问答社区](http://qiniu.segmentfault.com/)
- 更详细的文档, 见 [官方文档站](http://developer.qiniu.com/)
- 如果发现了 bug, 欢迎提交 [issue](https://github.com/qiniu/objc-sdk/issues)
- 如果有功能需求, 欢迎提交 [issue](https://github.com/qiniu/objc-sdk/issues)
- 如果要提交代码, 欢迎提交 pull request
- 欢迎关注我们的 [微信](http://www.qiniu.com/#weixin) && [微博](http://weibo.com/qiniutek), 及时获取动态信息

## 代码许可

The MIT License (MIT). 详情见 [License 文件](https://github.com/qiniu/objc-sdk/blob/master/LICENSE).
