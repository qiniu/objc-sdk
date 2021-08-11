//
//  QNPHAssetFile.m
//  Pods
//
//  Created by   何舒 on 15/10/21.
//
//

#import "QNPHAssetFile.h"
#import <Photos/Photos.h>
#import "QNResponseInfo.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90100)

@interface QNPHAssetFile ()

@property (nonatomic) PHAsset *phAsset;

@property (nonatomic) int64_t fileSize;

@property (nonatomic) int64_t fileModifyTime;

@property (nonatomic, strong) NSData *assetData;

// file path 可能是导出的 file path，并不是真正的 filePath, 导出的文件在上传结束会被删掉，并不是真正有效的文件路径。
@property(nonatomic, assign)BOOL hasRealFilePath;
@property (nonatomic, copy) NSString *filePath;

@property (nonatomic) NSFileHandle *file;

@property (nonatomic, strong) NSLock *lock;

@end

@implementation QNPHAssetFile

- (instancetype)init:(PHAsset *)phAsset error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        NSDate *createTime = phAsset.creationDate;
        int64_t t = 0;
        if (createTime != nil) {
            t = [createTime timeIntervalSince1970];
        }
        _fileModifyTime = t;
        _phAsset = phAsset;
        [self getInfo];
        
        _lock = [[NSLock alloc] init];
        if (self.assetData == nil && self.filePath != nil) {
            NSError *error2 = nil;
            NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:&error2];
            if (error2 != nil) {
                if (error != nil) {
                    *error = error2;
                }
                return self;
            }
            _fileSize = [fileAttr fileSize];
            NSFileHandle *f = nil;
            NSData *d = nil;
            if (_fileSize > 16 * 1024 * 1024) {
                f = [NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:self.filePath] error:error];
                if (f == nil) {
                    if (error != nil) {
                        *error = [[NSError alloc] initWithDomain:self.filePath code:kQNFileError userInfo:[*error userInfo]];
                    }
                    return self;
                }
            } else {
                d = [NSData dataWithContentsOfFile:self.filePath options:NSDataReadingMappedIfSafe error:&error2];
                if (error2 != nil) {
                    if (error != nil) {
                        *error = error2;
                    }
                    return self;
                }
            }
            _file = f;
            _assetData = d;
        }
    }
    return self;
}

- (NSData *)read:(long)offset
            size:(long)size
           error:(NSError **)error {
    
    NSData *data = nil;
    @try {
        [_lock lock];
        if (_assetData != nil) {
            data = [_assetData subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
        } else {
            [_file seekToFileOffset:offset];
            data = [_file readDataOfLength:size];
        }
    } @catch (NSException *exception) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:kQNFileError userInfo:@{NSLocalizedDescriptionKey : exception.reason}];
        NSLog(@"read file failed reason: %@ \n%@", exception.reason, exception.callStackSymbols);
    } @finally {
        [_lock unlock];
    }
    return data;
}

- (NSData *)readAllWithError:(NSError **)error {
    return [self read:0 size:(long)_fileSize error:error];
}

- (void)close {
    if (PHAssetMediaTypeVideo == self.phAsset.mediaType) {
        if (_file != nil) {
            [_file closeFile];
        }
        // 如果是导出的 file 删除
        if (!self.hasRealFilePath && self.filePath) {
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
        }
    }
}

- (NSString *)path {
    return self.hasRealFilePath ? self.filePath : nil;
}

- (int64_t)modifyTime {
    return _fileModifyTime;
}

- (int64_t)size {
    return _fileSize;
}

- (void)getInfo {
    if (PHAssetMediaTypeImage == self.phAsset.mediaType) {
        [self getImageInfo];
    } else if (PHAssetMediaTypeVideo == self.phAsset.mediaType) {
        // 1. 获取 video url
//        [self getVideoInfo];
        
        // 2. video url 获取失败则导出文件
        if (self.filePath == nil) {
            [self exportAssert];
        }
    } else {
        [self exportAssert];
    }
}

- (void)getImageInfo {
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.resizeMode = PHImageRequestOptionsResizeModeNone;
    //不支持icloud上传
    options.networkAccessAllowed = NO;
    options.synchronous = YES;

    [[PHImageManager defaultManager] requestImageDataForAsset:self.phAsset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        self.assetData = imageData;
        self.fileSize = imageData.length;
        self.hasRealFilePath = NO;
    }];
}

- (void)getVideoInfo {
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHVideoRequestOptionsVersionCurrent;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
    //不支持icloud上传
    options.networkAccessAllowed = NO;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [[PHImageManager defaultManager] requestAVAssetForVideo:self.phAsset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            self.filePath = [[(AVURLAsset *)asset URL] path];
            self.hasRealFilePath = YES;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)exportAssert {
    NSArray *assetResources = [PHAssetResource assetResourcesForAsset:self.phAsset];
    PHAssetResource *resource;
    for (PHAssetResource *assetRes in assetResources) {
        if (assetRes.type == PHAssetResourceTypePairedVideo || assetRes.type == PHAssetResourceTypeVideo) {
            resource = assetRes;
        }
    }
    NSString *fileName = [NSString stringWithFormat:@"tempAsset-%@.mov", [NSDate date]];
    if (resource.originalFilename) {
        fileName = resource.originalFilename;
    }
    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    //不支持icloud上传
    options.networkAccessAllowed = NO;

    NSString *PATH_VIDEO_FILE = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] removeItemAtPath:PATH_VIDEO_FILE error:nil];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resource toFile:[NSURL fileURLWithPath:PATH_VIDEO_FILE] options:options completionHandler:^(NSError *_Nullable error) {
        if (error) {
            self.filePath = nil;
        } else {
            self.filePath = PATH_VIDEO_FILE;
        }
        self.hasRealFilePath = NO;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

@end

#endif
