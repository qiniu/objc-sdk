//
//  QNConfiguration.m
//  QiniuSDK
//
//  Created by bailong on 15/5/21.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import "QNConfiguration.h"
#import "QNResponseInfo.h"
#import "QNUpToken.h"
#import "QNReportConfig.h"
#import "QNAutoZone.h"
#import "QN_GTM_Base64.h"

const UInt32 kQNBlockSize = 4 * 1024 * 1024;
const UInt32 kQNDefaultDnsCacheTime = 2 * 60;


@implementation QNConfiguration

+ (instancetype)defaultConfiguration{
    QNConfigurationBuilder *builder = [[QNConfigurationBuilder alloc] init];
    return [[QNConfiguration alloc] initWithBuilder:builder];
}

+ (instancetype)build:(QNConfigurationBuilderBlock)block {
    QNConfigurationBuilder *builder = [[QNConfigurationBuilder alloc] init];
    block(builder);
    return [[QNConfiguration alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(QNConfigurationBuilder *)builder {
    if (self = [super init]) {
        _useConcurrentResumeUpload = builder.useConcurrentResumeUpload;
        _resumeUploadVersion = builder.resumeUploadVersion;
        _concurrentTaskCount = builder.concurrentTaskCount;
        
        _chunkSize = builder.chunkSize;
        if (builder.resumeUploadVersion == QNResumeUploadVersionV1) {
            if (_chunkSize < 1024) {
                _chunkSize = 1024;
            }
        } else if (builder.resumeUploadVersion == QNResumeUploadVersionV2) {
            if (_chunkSize < 1024 * 1024) {
                _chunkSize = 1024 * 1024;
            }
        }
        
        _putThreshold = builder.putThreshold;
        _retryMax = builder.retryMax;
        _retryInterval = builder.retryInterval;
        _timeoutInterval = builder.timeoutInterval;

        _recorder = builder.recorder;
        _recorderKeyGen = builder.recorderKeyGen;

        _proxy = builder.proxy;

        _converter = builder.converter;
        
        _zone = builder.zone;

        _useHttps = builder.useHttps;

        _allowBackupHost = builder.allowBackupHost;
        _accelerateUploading = builder.accelerateUploading;

    }
    return self;
}

@end


@interface QNGlobalConfiguration(){
    NSArray *_defaultDohIpv4Servers;
    NSArray *_defaultDohIpv6Servers;
    NSArray *_defaultUdpDnsIpv4Servers;
    NSArray *_defaultUdpDnsIpv6Servers;
    NSArray *_defaultConnectCheckUrls;
}

@property(nonatomic, strong)NSArray *defaultDohIpv4Servers;
@property(nonatomic, strong)NSArray *defaultDohIpv6Servers;
@property(nonatomic, strong)NSArray *defaultUdpDnsIpv4Servers;
@property(nonatomic, strong)NSArray *defaultUdpDnsIpv6Servers;
@property(nonatomic, strong)NSArray *defaultConnectCheckUrls;
@end
@implementation QNGlobalConfiguration
+ (instancetype)shared{
    static QNGlobalConfiguration *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[QNGlobalConfiguration alloc] init];
        [config setupData];
    });
    return config;
}
- (void)setupData{
    _isDnsOpen = YES;
    _dnsResolveTimeout = 2;
    _dnsCacheDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/Dns"];
    _dnsRepreHostNum = 2;
    _dnsCacheTime = kQNDefaultDnsCacheTime;
    _dnsCacheMaxTTL = 10*60;
    
    _dohEnable = true;
    _defaultDohIpv4Servers = [self parseBase64Array:@"WyJodHRwczovLzIyMy42LjYuNi9kbnMtcXVlcnkiLCAiaHR0cHM6Ly84LjguOC44L2Rucy1xdWVyeSJd"];
    
    _udpDnsEnable = true;
    _defaultUdpDnsIpv4Servers = [self parseBase64Array:@"WyIyMjMuNS41LjUiLCAiMTE0LjExNC4xMTQuMTE0IiwgIjEuMS4xLjEiLCAiOC44LjguOCJd"];
    
    _globalHostFrozenTime = 10;
    _partialHostFrozenTime = 5*60;
    
    _connectCheckEnable = YES;
    _connectCheckTimeout = 2;
    _defaultConnectCheckUrls = [self parseBase64Array:@"WyJodHRwczovL3d3dy5xaW5pdS5jb20iLCAiaHR0cHM6Ly93d3cuYmFpZHUuY29tIiwgImh0dHBzOi8vd3d3Lmdvb2dsZS5jb20iXQ=="];
    _connectCheckURLStrings = nil;
}

- (NSArray *)parseBase64Array:(NSString *)data {
    NSData *jsonData = [QN_GTM_Base64 decodeData:[data dataUsingEncoding:NSUTF8StringEncoding]];
    NSArray *ret = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
    if (ret && [ret isKindOfClass:[NSArray class]]) {
        return ret;
    }
    return nil;
}

- (BOOL)isDohEnable {
    return _dohEnable && (self.dohIpv4Servers.count > 0 || self.dohIpv6Servers.count > 0) ;
}

- (NSArray<NSString *> *)dohIpv4Servers {
    if (_dohIpv4Servers) {
        return _dohIpv4Servers;
    } else {
        return self.defaultDohIpv4Servers;
    }
}

- (NSArray<NSString *> *)dohIpv6Servers {
    if (_dohIpv6Servers) {
        return _dohIpv6Servers;
    } else {
        return self.defaultDohIpv6Servers;
    }
}

- (NSArray<NSString *> *)udpDnsIpv4Servers {
    if (_udpDnsIpv4Servers) {
        return _udpDnsIpv4Servers;
    } else {
        return self.defaultUdpDnsIpv4Servers;
    }
}

- (NSArray<NSString *> *)udpDnsIpv6Servers {
    if (_udpDnsIpv6Servers) {
        return _udpDnsIpv6Servers;
    } else {
        return self.defaultUdpDnsIpv6Servers;
    }
}

- (BOOL)isUdpDnsEnable {
    return _udpDnsEnable && (self.udpDnsIpv4Servers.count > 0 || self.udpDnsIpv6Servers.count > 0) ;
}

- (NSArray<NSString *> *)connectCheckURLStrings {
    if (_connectCheckURLStrings) {
        return _connectCheckURLStrings;
    } else {
        return self.defaultConnectCheckUrls;
    }
}

- (NSArray *)defaultDohIpv4Servers {
    NSArray *arr = nil;
    @synchronized (self) {
        if (_defaultDohIpv4Servers) {
            arr = [_defaultDohIpv4Servers copy];
        }
    }
    return arr;
}

- (void)setDefaultDohIpv4Servers:(NSArray *)defaultDohIpv4Servers {
    @synchronized (self) {
        _defaultDohIpv4Servers = defaultDohIpv4Servers;
    }
}

- (NSArray *)defaultDohIpv6Servers {
    NSArray *arr = nil;
    @synchronized (self) {
        if (_defaultDohIpv6Servers) {
            arr = [_defaultDohIpv6Servers copy];
        }
    }
    return arr;
}

- (void)setDefaultDohIpv6Servers:(NSArray *)defaultDohIpv6Servers {
    @synchronized (self) {
        _defaultDohIpv6Servers = defaultDohIpv6Servers;
    }
}


- (NSArray *)defaultUdpDnsIpv4Servers {
    NSArray *arr = nil;
    @synchronized (self) {
        if (_defaultUdpDnsIpv4Servers) {
            arr = [_defaultUdpDnsIpv4Servers copy];
        }
    }
    return arr;
}

- (void)setDefaultUdpDnsIpv4Servers:(NSArray *)defaultUdpDnsIpv4Servers {
    @synchronized (self) {
        _defaultUdpDnsIpv4Servers = defaultUdpDnsIpv4Servers;
    }
}


- (NSArray *)defaultUdpDnsIpv6Servers {
    NSArray *arr = nil;
    @synchronized (self) {
        if (_defaultUdpDnsIpv6Servers) {
            arr = [_defaultUdpDnsIpv6Servers copy];
        }
    }
    return arr;
}

- (void)setDefaultUdpDnsIpv6Servers:(NSArray *)defaultUdpDnsIpv6Servers {
    @synchronized (self) {
        _defaultUdpDnsIpv6Servers = defaultUdpDnsIpv6Servers;
    }
}

- (NSArray *)defaultConnectCheckUrls {
    NSArray *arr = nil;
    @synchronized (self) {
        if (_defaultConnectCheckUrls) {
            arr = [_defaultConnectCheckUrls copy];
        }
    }
    return arr;
}

- (void)setDefaultConnectCheckUrls:(NSArray *)defaultConnectCheckUrls {
    @synchronized (self) {
        _defaultConnectCheckUrls = defaultConnectCheckUrls;
    }
}


@end

@implementation QNConfigurationBuilder

- (instancetype)init {
    if (self = [super init]) {
        _zone = [[QNAutoZone alloc] init];
        _chunkSize = 2 * 1024 * 1024;
        _putThreshold = 4 * 1024 * 1024;
        _retryMax = 1;
        _timeoutInterval = 90;
        _retryInterval = 0.5;

        _recorder = nil;
        _recorderKeyGen = nil;

        _proxy = nil;
        _converter = nil;

        _useHttps = YES;
        _allowBackupHost = YES;
        _accelerateUploading = NO;
        _useConcurrentResumeUpload = NO;
        _resumeUploadVersion = QNResumeUploadVersionV1;
        _concurrentTaskCount = 3;
    }
    return self;
}

@end

