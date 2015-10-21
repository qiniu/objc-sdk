//
//  QNPHAssetFile.m
//  QiniuSDK
//
//  Created by su xinde on 15/10/22.
//  Copyright © 2015年 Qiniu. All rights reserved.
//

#import "QNPHAssetFile.h"

#import <Photos/Photos.h>

enum {
    kAMASSETMETADATA_PENDINGREADS = 1,
    kAMASSETMETADATA_ALLFINISHED = 0
};

@interface QNPHAssetFile ()
{
    BOOL _hasGotInfo;
}
@property (nonatomic) PHAsset *asset;

@property (readonly)  int64_t fileSize;

@property (readonly)  int64_t fileModifyTime;

@property (nonatomic, strong) NSData *assetData;

@property (nonatomic, strong) NSURL *assetURL;

@end

@implementation QNPHAssetFile

@synthesize assetData = _assetData;
@synthesize asset = _asset;
@synthesize assetURL = _assetURL;

/**
 *    打开指定文件
 *
 *    @param path      文件路径
 *    @param error     输出的错误信息
 *
 *    @return 实例
 */
- (instancetype)init:(PHAsset *)asset
               error:(NSError *__autoreleasing *)error
{
    if (self = [super init]) {
        NSDate *createTime = asset.creationDate;
        int64_t t = 0;
        if (createTime != nil) {
            t = [createTime timeIntervalSince1970];
        }
        _fileModifyTime = t;
        self.asset = asset;
        
        [self getInfo];
    }
    
    return self;
}

- (void)dealloc
{
    _assetData = nil;
    _asset = nil;
    _assetURL = nil;
}

- (NSData *)fetchDataFromAsset:(PHAsset *)asset
{
    __block NSData *tmpData = nil;
    
    // Image
    if (asset.mediaType == PHAssetMediaTypeImage) {
        
        PHImageRequestOptions *request = [PHImageRequestOptions new];
        request.version = PHImageRequestOptionsVersionCurrent;
        request.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        request.resizeMode = PHImageRequestOptionsResizeModeNone;
        request.synchronous = YES;
        
        [[PHImageManager defaultManager] requestImageDataForAsset:asset
                                                          options:request
                                                    resultHandler:
         ^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
             tmpData = [NSData dataWithData:imageData];
         }];
    }
    // Video
    else  {
        
        PHVideoRequestOptions *request = [PHVideoRequestOptions new];
        request.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
        request.version = PHVideoRequestOptionsVersionCurrent;
        
        NSConditionLock *assetReadLock = [[NSConditionLock alloc] initWithCondition:kAMASSETMETADATA_PENDINGREADS];
        
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset
                                                        options:request
                                                  resultHandler:
         ^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
             AVURLAsset *urlAsset = (AVURLAsset *)asset;
             NSData *videoData = [NSData dataWithContentsOfURL:urlAsset.URL];
             tmpData = [NSData dataWithData:videoData];
             
             [assetReadLock lock];
             [assetReadLock unlockWithCondition:kAMASSETMETADATA_ALLFINISHED];
         }];
        
        [assetReadLock lockWhenCondition:kAMASSETMETADATA_ALLFINISHED];
        [assetReadLock unlock];
        assetReadLock = nil;
    }
    
    
    
    return tmpData;
}

- (void)getInfo
{
    if (!_hasGotInfo) {
        _hasGotInfo = YES;
        
        if (PHAssetMediaTypeImage == self.asset.mediaType) {
            PHImageRequestOptions *request = [PHImageRequestOptions new];
            request.version = PHImageRequestOptionsVersionCurrent;
            request.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            request.resizeMode = PHImageRequestOptionsResizeModeNone;
            request.synchronous = YES;
            
            [[PHImageManager defaultManager] requestImageDataForAsset:self.asset
                                                              options:request
                                                        resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                                                            _fileSize = imageData.length;
                                                            _assetURL = [NSURL URLWithString:self.asset.localIdentifier];
                                                        }
             ];
        }
        else if (PHAssetMediaTypeVideo == self.asset.mediaType) {
            PHVideoRequestOptions *request = [PHVideoRequestOptions new];
            request.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
            request.version = PHVideoRequestOptionsVersionCurrent;
            
            NSConditionLock* assetReadLock = [[NSConditionLock alloc] initWithCondition:kAMASSETMETADATA_PENDINGREADS];
            [[PHImageManager defaultManager] requestPlayerItemForVideo:self.asset options:request resultHandler:^(AVPlayerItem *playerItem, NSDictionary *info) {
                AVURLAsset *urlAsset = (AVURLAsset *)playerItem.asset;
                NSNumber *fileSize = nil;;
                [urlAsset.URL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
                _fileSize = [fileSize unsignedLongLongValue];
                _assetURL = urlAsset.URL;
                
                [assetReadLock lock];
                [assetReadLock unlockWithCondition:kAMASSETMETADATA_ALLFINISHED];
            }];
            [assetReadLock lockWhenCondition:kAMASSETMETADATA_ALLFINISHED];
            [assetReadLock unlock];
            assetReadLock = nil;
        }
    }
    
}

#pragma mark - QNFileDelegate

/**
 *    从指定偏移读取数据
 *
 *    @param offset 偏移地址
 *    @param size   大小
 *
 *    @return 数据
 */
- (NSData *)read:(long)offset
            size:(long)size
{
    NSData *data = [self readAll];
    NSRange subRange = NSMakeRange(offset, size);
    NSData *subData = [data subdataWithRange:subRange];
    return subData;
}

/**
 *    读取所有文件内容
 *
 *    @return 数据
 */
- (NSData *)readAll
{
    if (self.assetData) {
        return self.assetData;
    }else {
        self.assetData = [self fetchDataFromAsset:self.asset];
        return self.assetData;
    }
}

/**
 *    关闭文件
 *
 */
- (void)close
{
    
}

/**
 *    文件路径
 *
 *    @return 文件路径
 */
- (NSString *)path
{
    return _assetURL.path;
}

/**
 *    文件修改时间
 *
 *    @return 修改时间
 */
- (int64_t)modifyTime
{
    return _fileModifyTime;
}

/**
 *    文件大小
 *
 *    @return 文件大小
 */
- (int64_t)size
{
    return _fileSize;
}

@end
