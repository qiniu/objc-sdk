//
//  QNPHAssetResource.m
//  QiniuSDK
//
//  Created by   何舒 on 16/2/14.
//  Copyright © 2016年 Qiniu. All rights reserved.
//

#import "QNPHAssetResource.h"
#import <Photos/Photos.h>
#import "QNResponseInfo.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)

enum {
    kAMASSETMETADATA_PENDINGREADS = 1,
    kAMASSETMETADATA_ALLFINISHED = 0
};

@interface QNPHAssetResource ()

@property (nonatomic) PHAssetResource *phAssetResource;

@property (nonatomic) int64_t fileSize;

@property (nonatomic) int64_t fileModifyTime;

@property (nonatomic, strong) NSData *assetData;

@property (nonatomic, assign)BOOL hasRealFilePath;
@property (nonatomic,   copy) NSString *filePath;
@property (nonatomic, strong) NSFileHandle *file;

@property (nonatomic, strong) NSLock *lock;

@end

@implementation QNPHAssetResource
- (instancetype)init:(PHAssetResource *)phAssetResource
               error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        PHFetchResult<PHAsset *> *results = [PHAsset fetchAssetsWithBurstIdentifier:phAssetResource.assetLocalIdentifier options:nil];
        if (results.firstObject != nil) {
            PHAsset *phasset = results.firstObject;
            NSDate *createTime = phasset.creationDate;
            int64_t t = 0;
            if (createTime != nil) {
                t = [createTime timeIntervalSince1970];
            }
            _fileModifyTime = t;
        }
        
        _phAssetResource = phAssetResource;
        _lock = [[NSLock alloc] init];
        [self getInfo:error];
    }
    return self;
}

- (NSData *)read:(long long)offset
            size:(long)size
           error:(NSError **)error {
    
    NSData *data = nil;
    @try {
        [_lock lock];
        if (_assetData != nil && offset < _assetData.length) {
            NSUInteger realSize = MIN((NSUInteger)size, _assetData.length - (NSUInteger)offset);
            data = [_assetData subdataWithRange:NSMakeRange((NSUInteger)offset, realSize)];
        } else if (_file != nil && offset < _fileSize) {
            [_file seekToFileOffset:offset];
            data = [_file readDataOfLength:size];
        } else {
            data = [NSData data];
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
    if (self.file) {
        [self.file closeFile];
    }
    
    // 如果是导出的 file 删除
    if (self.filePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
    }
}

- (NSString *)path {
    return self.filePath ? self.filePath : nil;
}

- (int64_t)modifyTime {
    return _fileModifyTime;
}

- (int64_t)size {
    return _fileSize;
}

- (NSString *)fileType {
    return @"PHAssetResource";
}

- (void)getInfo:(NSError **)error {
    [self exportAssert];
    
    NSError *error2 = nil;
    NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:&error2];
    if (error2 != nil) {
        if (error != nil) {
            *error = error2;
        }
        return;
    }
    
    _fileSize = [fileAttr fileSize];
    NSFileHandle *file = nil;
    NSData *data = nil;
    if (_fileSize > 16 * 1024 * 1024) {
        file = [NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:self.filePath] error:error];
        if (file == nil) {
            if (error != nil) {
                *error = [[NSError alloc] initWithDomain:self.filePath code:kQNFileError userInfo:[*error userInfo]];
            }
            return;
        }
    } else {
        data = [NSData dataWithContentsOfFile:self.filePath options:NSDataReadingMappedIfSafe error:&error2];
        if (error2 != nil) {
            if (error != nil) {
                *error = error2;
            }
            return;
        }
    }
    
    self.file = file;
    self.assetData = data;
}

- (void)exportAssert {
    PHAssetResource *resource = self.phAssetResource;
    NSString *fileName = [NSString stringWithFormat:@"tempAsset-%f-%d.mov", [[NSDate date] timeIntervalSince1970], arc4random()%100000];
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
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

@end

#endif
