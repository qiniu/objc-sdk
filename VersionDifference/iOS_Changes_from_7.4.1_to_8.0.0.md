
## 1. 开放文件
#### 1.1 8.0.0 废除
```
#import "QNHttpResponseInfo.h" 
#import "QNUploadInfoReporter.h" 
```

#### 1.1 8.0.0 新增
```
#import "QNReportConfig.h"  
```


## 2. 主要开放类版本对比
#### 2.1 QNZone
接口变更：
##### 2.1.1 调整：
```
QNPrequeryReturn:【内部使用】
// 7.4.1：
typedef void (^QNPrequeryReturn)(int code, QNHttpResponseInfo * _Nullable httpResponseInfo);
// 8.0.0:
typedef void (^QNPrequeryReturn)(int code, QNResponseInfo * _Nullable httpResponseInfo, QNUploadRegionRequestMetrics * _Nullable metrics);

```

##### 2.1.2 废除：
```
- (NSString *)upHost:(QNZoneInfo *)zoneInfo
             isHttps:(BOOL)isHttps
          lastUpHost:(NSString *)lastUpHost;  【内部使用】
- (NSString *)up:(QNUpToken * _Nullable)token
    zoneInfoType:(QNZoneInfoType)zoneInfoType
         isHttps:(BOOL)isHttps
    frozenDomain:(NSString * _Nullable)frozenDomain; 【内部使用】
```

#### 2.2 QNFixedZone
接口变更：
##### 2.2.1 调整：
```
// 7.4.1：
+ (NSArray <QNFixedZone *> *)localsZoneInfo;
// 8.0.0:
+ (QNFixedZone *)localsZoneInfo;
```

#### 2.3 QNAutoZone
接口变更：无

#### 2.4 QNFileRecorder
接口变更：无

#### 2.5 QNResponseInfo
接口变更：
##### 2.5.1 新增
```
// error 类型：
extern const int kQNLocalIOError;
extern const int kQNMaliciousResponseError;

// property:
@property (nonatomic, copy, readonly) NSDictionary *responseDictionary;
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, readonly) BOOL isTlsError;
@property (nonatomic, readonly) BOOL couldRetry; 【内部使用】
@property (nonatomic, readonly) BOOL couldHostRetry;【内部使用】
@property (nonatomic, readonly) BOOL couldRegionRetry; 【内部使用】
```

##### 2.5.1 调整
以下调整均为【内部使用】，外部不推荐使用，详情见代码注释
```
// 7.4.1：
+ (instancetype)cancelWithDuration:(double)duration;
+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc duration:(double)duration;
+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc duration:(double)duration;
+ (instancetype)responseInfoWithFileError:(NSError *)error duration:(double)duration;
+ (instancetype)responseInfoOfZeroData:(NSString *)path duration:(double)duration;
+ (instancetype)responseInfoWithHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo duration:(double)duration;

// 8.0.0:
+ (instancetype)cancelResponse;
+ (instancetype)responseInfoWithNetworkError:(NSString *)desc;
+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc;
+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc;
+ (instancetype)responseInfoWithFileError:(NSError *)error;
+ (instancetype)responseInfoOfZeroData:(NSString *)path;
+ (instancetype)responseInfoWithLocalIOError:(NSString *)desc;

```

##### 2.5.2 新增
```
// 8.0.0
+ (instancetype)errorResponseInfo:(int)errorType
                        errorDesc:(NSString *)errorDesc;
- (instancetype)initWithResponseInfoHost:(NSString *)host
                                response:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error;
```

#### 2.6 QNUploadManager
接口变更：无

#### 2.7 QNUploadOption
接口变更：无

#### 2.8 QNUrlSafeBase64
接口变更：无

#### 2.9 QNReportConfig 
接口变更：无

#### 2.10 QNPipeline
接口变更：无
