//
//  Uploader.m
//  QiniuDemo
//
//  Created by yangsen on 2024/7/9.
//  Copyright © 2024 Aaron. All rights reserved.
//

#import "Uploader.h"
#import <QiniuSDK.h>

@implementation Uploader

- (void)upload {
    
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        // Upload_Domain1 和 Upload_Domain2 为加速域名，可以参考七牛云存储控制台域名管理页面，建议通过用户服务下发，不要硬编码
        builder.zone =  [[QNFixedZone alloc] initWithUpDomainList:@[@"Upload_Domain1", @"Upload_Domain2"]];
    }];
    
    QNUploadManager *manager = [[QNUploadManager alloc] initWithConfiguration:config];
    
    //    QNFixedZone *zone = [QNFixedZone createWithRegionId:@"z0"];
    
    QNAutoZone *zone = [QNAutoZone zoneWithUcHosts:@[@"UCHost0", @"UCHost1"]];
    
}

- (void)upload0 {
    
    
    QNConfiguration *configuration = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        // 配置上传区域，Host0、Host1 建议通过服务方式下发
        builder.zone = [[QNFixedZone alloc] initWithUpDomainList:@[@"Host0", @"Host2"]];
        // 分片上传阈值：4MB，大于 4MB 采用分片上传，小于 4MB 采用表单上传
        builder.putThreshold = 4*1024*1024;
        // 开启并发分片上传
        builder.useConcurrentResumeUpload = true;
        // 使用分片 V2
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
        // 文件分片上传时断点续传信息保存，表单上传此配置无效
        NSString *recorderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:recorderPath error:nil];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:configuration];
    
    __weak typeof(self) weakSelf = self;
    QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        NSLog(@"percent == %.2f", percent);
    }
                                                                 params:nil
                                                               checkCrc:NO
                                                     cancellationSignal:^BOOL{
        // 当需要取消时，此处返回 true，SDK 内部会多次检查返回值，当返回值为 true 时会取消上传操作
        return false;
    }];
    
    NSString *filePath = @"";    // 文件路径
    NSString *key = @"";         // 文件 key
    NSString *uploadToken = @""; // 上传的 Token
    [upManager putFile:filePath key:key token:uploadToken complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        if (info.isOK) {
            // 上传成功
        } else {
            // 上传失败
        }
    } option:uploadOption];
}


- (void)upload1 {
    
    QNConfiguration *configuration = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.zone = [[QNAutoZone alloc] init]; // 配置上传区域，使用 QNAutoZone
        builder.recorderKeyGen = ^NSString *(NSString *uploadKey, NSString *filePath) {
            // 自定义 文件分片上传时断点续传信息保存的 key，默认使用 uploadKey
            return [NSString stringWithFormat:@"%@-%@", uploadKey, filePath];
        };
        // 文件分片上传时断点续传信息保存，表单上传此配置无效
        NSString *recorderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:recorderPath error:nil];

        // 文件采用分片上传时，分片大小为 2MB
        builder.chunkSize = 2*1024*1024;
        
        // 分片上传阈值：4MB，大于 4MB 采用分片上传，小于 4MB 采用表单上传
        builder.putThreshold = 4*1024*1024;
        
        // 单个域名/IP请求失败后最大重试次数为 1 次
        builder.retryMax = 1;
        
        // 重试时间间隔：0.5s
        builder.retryInterval = 0.5;
        
        // 请求超时时间：60s
        builder.timeoutInterval = 60;
        
        // 使用 HTTPS
        builder.useHttps = true;
        
        // 使用备用域名进行重试
        builder.allowBackupHost = true;
        
        // 开启加速上传
        builder.accelerateUploading = true;
       
        // 开启并发分片上传
        builder.useConcurrentResumeUpload = true;
        
        // 使用并发分片上传时，一个文件并发上传的分片个数
        builder.concurrentTaskCount = 2;
        
        // 使用分片 V2
        builder.resumeUploadVersion = QNResumeUploadVersionV2;
    }];
    
    
    // 指定文件 mime type
    NSString *mimeType = @"";
    // 用于服务器上传回调通知的自定义参数，参数的key必须以x: 开头  eg: x:foo
    NSDictionary <NSString *, NSString *> * params = @{};
    // 用于设置meta数据，参数的key必须以x-qn-meta- 开头  eg: x-qn-meta-key
    NSDictionary <NSString *, NSString *> * metaDataParams = @{};
    BOOL checkCrc = true;
    QNUploadOption *option = [[QNUploadOption alloc] initWithMime:mimeType
                                              byteProgressHandler:^(NSString *key, long long uploadBytes, long long totalBytes) {
        // 处理上传进度
    } params:params metaDataParams:metaDataParams checkCrc:checkCrc cancellationSignal:^BOOL{
        // 当需要取消时，此处返回 false，SDK 内部会不间断检测此返回值
        return false;
    }];
    
    
}
@end
