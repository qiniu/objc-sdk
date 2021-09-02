//
//  QNUploadSource.h
//  QiniuSDK
//
//  Created by yangsen on 2021/5/10.
//  Copyright © 2021 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNUploadSource <NSObject>

/**
 * 获取资源唯一标识
 * 作为断点续传时判断是否为同一资源的依据之一；
 * 如果两个资源的 record key 和 资源唯一标识均相同则认为资源为同一资源，断点续传才会生效
 * 注：
 * 同一资源的数据必须完全相同，否则上传可能会出现异常
 *
 * @return 资源修改时间
 */
- (NSString *)getId;

/**
 * 是否可以重新加载文件信息，也即是否可以重新读取信息
 * @return return
 */
- (BOOL)couldReloadSource;

/**
 * 重新加载文件信息，以便于重新读取
 *
 * @return 重新加载是否成功
 */
- (BOOL)reloadSource;

/**
 * 获取资源文件名
 * @return 资源文件名
 */
- (NSString *)getFileName;

/**
 * 获取资源大小
 * 无法获取大小时返回 -1
 * 作用：
 * 1. 验证资源是否为同一资源
 * 2. 计算上传进度
 *
 * @return 资源大小
 */
- (long long)getSize;

/**
 * 读取数据
 * 1. 返回 byte[] 可能为空，但不会为 null；
 * 2. 当 byte[] 大小和 dataSize 不同时，则源数据已经读取结束
 * 3. 读取异常时抛出 error
 * 4. 仅支持串行调用，且 dataOffset 依次递增
 *
 * @param dataSize 数据大小
 * @param dataOffset 数据偏移量
 * @param error 异常时的错误信息
 * @return 数据
 */
- (NSData *)readData:(NSInteger)dataSize dataOffset:(long)dataOffset error:(NSError **)error;

/**
 * 关闭流
 */
- (void)close;

@end

#define kQNUnknownSourceSize -1

NS_ASSUME_NONNULL_END
