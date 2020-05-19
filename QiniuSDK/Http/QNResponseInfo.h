//
//  QNResponseInfo.h
//  QiniuSDK
//
//  Created by bailong on 14/10/2.
//  Copyright (c) 2014年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QNHttpResponseInfo;

/**
 *    中途取消的状态码
 */
extern const int kQNRequestCancelled;

/**
 *    网络错误状态码
 */
extern const int kQNNetworkError;

/**
 *    错误参数状态码
 */
extern const int kQNInvalidArgument;

/**
 *    0 字节文件或数据
 */
extern const int kQNZeroDataSize;

/**
 *    错误token状态码
 */
extern const int kQNInvalidToken;

/**
 *    读取文件错误状态码
 */
extern const int kQNFileError;

/**
 *    上传完成后返回的状态信息
 */
@interface QNResponseInfo : NSObject

/**
 *    状态码
 */
@property (readonly) int statusCode;

/**
 *    七牛服务器生成的请求ID，用来跟踪请求信息，如果使用过程中出现问题，请反馈此ID
 */
@property (nonatomic, copy, readonly) NSString *reqId;

/**
 *    七牛日志上报返回的X_Log_Client_Id
 */
@property (nonatomic, copy, readonly) NSString *xClientId;

/**
 *    七牛服务器内部跟踪记录
 */
@property (nonatomic, copy, readonly) NSString *xlog;

/**
 *    cdn服务器内部跟踪记录
 */
@property (nonatomic, copy, readonly) NSString *xvia;

/**
 *    错误信息，出错时请反馈此记录
 */
@property (nonatomic, copy, readonly) NSError *error;

/**
 *    服务器域名
 */
@property (nonatomic, copy, readonly) NSString *host;

/**
 *    请求消耗的时间，单位 秒
 */
@property (nonatomic, readonly) double duration;

/**
 *    客户端id
 */
@property (nonatomic, readonly) NSString *id;

/**
 *    时间戳
 */
@property (readonly) UInt64 timeStamp;

/**
 *    是否取消
 */
@property (nonatomic, readonly, getter=isCancelled) BOOL canceled;

/**
 *    成功的请求
 */
@property (nonatomic, readonly, getter=isOK) BOOL ok;

/**
 *    是否网络错误
 */
@property (nonatomic, readonly, getter=isConnectionBroken) BOOL broken;

/**
 *    是否为 七牛响应
 */
@property (nonatomic, readonly, getter=isNotQiniu) BOOL notQiniu;

/**
 *    工厂函数，内部使用
 *
 *    @param duration   请求完成时间，单位秒
 *    
 *    @return 取消的实例
 */
+ (instancetype)cancelWithDuration:(double)duration;

/**
 *    工厂函数，内部使用
 *
 *    @param desc 错误参数描述
 *    @param duration   请求完成时间，单位秒
 *
 *    @return 错误参数实例
 */
+ (instancetype)responseInfoWithInvalidArgument:(NSString *)desc duration:(double)duration;

/**
 *    工厂函数，内部使用
 *
 *    @param desc 错误token描述
 *    @param duration   请求完成时间，单位秒
 *
 *    @return 错误token实例
 */
+ (instancetype)responseInfoWithInvalidToken:(NSString *)desc duration:(double)duration;

/**
 *    工厂函数，内部使用
 *
 *    @param error 错误信息
 *    @param duration   请求完成时间，单位秒
 *
 *    @return 文件错误实例
 */
+ (instancetype)responseInfoWithFileError:(NSError *)error duration:(double)duration;

/**
 *    工厂函数，内部使用
 *
 *    @param path        文件路径
 *    @param duration   请求完成时间，单位秒
 *
 *    @return 文件错误实例
 */
+ (instancetype)responseInfoOfZeroData:(NSString *)path duration:(double)duration;

/**
 *    工厂函数，内部使用
 *
 *    @param httpResponseInfo   最后一次http请求的信息
 *    @param duration   请求完成时间，单位秒
 *
 *    @return 实例
 */
+ (instancetype)responseInfoWithHttpResponseInfo:(QNHttpResponseInfo *)httpResponseInfo duration:(double)duration;

@end
