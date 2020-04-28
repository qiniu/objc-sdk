//
//  QNDnsCacheFile.m
//  QnDNS
//
//  Created by yangsen on 2020/3/26.
//  Copyright © 2020 com.qiniu. All rights reserved.
//

#import "QNDnsCacheFile.h"
#import "QNDnsCacheKey.h"

@interface QNDnsCacheFile()

@property(nonatomic,  copy)NSString *directory;

@end
@implementation QNDnsCacheFile

+ (instancetype)dnsCacheFile:(NSString *)directory
                       error:(NSError **)perror{
    
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:perror];
    if (*perror != nil) {
        return nil;
    }
    
    QNDnsCacheFile *f = [[QNDnsCacheFile alloc] init];
    f.directory = directory;
    return f;
}

- (NSError *)set:(NSString *)key
            data:(NSData *)value {
    NSError *error;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *subFilePaths = [fileManager subpathsAtPath:self.directory];
    for (NSString *path in subFilePaths) {
        [fileManager removeItemAtPath:path error:nil];
    }
    
    NSString *filePath = [self pathOfKey:key];
    [fileManager createFileAtPath:filePath contents:value attributes:nil];
    
    return error;
}

- (NSData *)get:(NSString *)key {
    return [NSData dataWithContentsOfFile:[self pathOfKey:key]];
}

- (NSError *)del:(NSString *)key {
    NSError *error = nil;
    NSString *path = [self pathOfKey:key];
    if (path) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:path error:&error];
    }
    return error;
}

- (NSString *)getFileName{
    
    NSString *fileName = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *subFilePaths = [fileManager subpathsAtPath:self.directory];
    
    if (subFilePaths && subFilePaths.count > 0) {
        
        if (subFilePaths.count == 1) {
            fileName = [subFilePaths.firstObject lastPathComponent];
        } else {
            
            double cacheTime = 0;
            for (NSString *path in subFilePaths) {
                
                NSString *fileNameP = [path lastPathComponent];
                QNDnsCacheKey *key = [QNDnsCacheKey dnsCacheKey:fileNameP];
                double time = [key.currentTime doubleValue];
                if (time > cacheTime) {
                    [self del:fileNameP];
                    cacheTime = time;
                    fileName = fileNameP;
                }
            }
        }
    }
    
    return fileName;
}

- (NSString *)pathOfKey:(NSString *)key {
    return [QNDnsCacheFile pathJoin:key path:_directory];
}

+ (NSString *)pathJoin:(NSString *)key
                  path:(NSString *)path {
    return [[NSString alloc] initWithFormat:@"%@/%@", path, key];
}

@end
