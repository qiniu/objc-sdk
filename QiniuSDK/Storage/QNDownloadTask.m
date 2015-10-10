//
//  QNDownloadTask.m
//  QiniuSDK
//
//  Created by ltz on 10/2/15.
//  Copyright © 2015 Qiniu. All rights reserved.
//




#include <arpa/inet.h>

#import "QNAsyncRun.h"
#import "QNDownloadTask.h"
#import "QNDownloadManager.h"

void setStat(NSMutableDictionary *dic, id key, id value) {
	if (value == nil) {
		return;
	}
	[dic setObject:value forKey:key];
}

BOOL isValidIPAddress(NSString *ip) {
	const char *utf8 = [ip UTF8String];
	if (utf8 == nil) {
		return true;
	}
	int success;

	struct in_addr dst;
	success = inet_pton(AF_INET, utf8, &dst);
	if (success != 1) {
		struct in6_addr dst6;
		success = inet_pton(AF_INET6, utf8, &dst6);
	}

	return success == 1;
}

typedef enum {
	TaskFailed = 0,
	TaskNotStarted,
	TaskGenerating,
	TaskNormal
} TaskStat;

typedef enum {
	TaskCreate = 0,
	TaskResume,
	TaskSuspend,
	TaskCancel
} TaskAction;

@interface QNDownloadTask ()

@property (nonatomic) QNDownloadManager *manager;
@property (nonatomic) NSURLSessionTask *realTask;
@property (nonatomic) NSMutableDictionary *stats;
@property (nonatomic) NSLock *lock;
@property TaskStat taskStat;
@property TaskAction expectedAction;


@property (nonatomic) NSURLRequest *oldRequest;
@property (nonatomic) NSProgress *progress;
@property (nonatomic, strong) QNDestinationBlock destination;
@property (nonatomic, strong) QNURLSessionTaskCompletionHandler completionHandler;

@end

@implementation QNDownloadTask

#if ( defined(__IPHONE_OS_VERSION_MAX_ALLOWED) &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || ( defined(MAC_OS_X_VERSION_MAX_ALLOWED) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9)

- (instancetype)        initWithStats:(NSMutableDictionary *)stats
                              manager:(QNDownloadManager *)manager
                              request:(NSURLRequest *)request
                             progress:(NSProgress *)progress
                          destination:(QNDestinationBlock)
        destination completionHandler:(QNURLSessionTaskCompletionHandler)completionHandler {

	self = [super init];
	_stats = stats;
	_oldRequest = request;
	_progress = progress;
	_destination = destination;
	_completionHandler = completionHandler;

	_realTask = nil;

	_manager = manager;
	_taskStat = TaskNotStarted;
	_expectedAction = TaskCreate;
	return self;
}


- (NSURLRequest *) newRequest:(NSURLRequest *)request {

	NSString *host = request.URL.host;
	setStat(_stats, @"domain", host);

	if (!isValidIPAddress(host)) {


		NSDate *s0 = [NSDate date];
		// 查询DNS
		NSArray *ips = [_manager.config.dns queryWithDomain:[[QNDomain alloc] init:host hostsFirst:NO hasCname:YES]];


		// 记录DNS查询时间
		NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:s0];
		[_stats setObject:[NSNumber numberWithInt:(int)(interval*1000)] forKey:@"dt"];
		if ([ips count] == 0) {
			// error;
			// TODO
			return nil;
		}

		// 记录实际请求的IP
		//        [stats setObject:ips[0] forKey:@"ip"];
		setStat(_stats, @"ip", ips[0]);
		NSRange range = [request.URL.absoluteString rangeOfString:request.URL.host];
		NSString *newURL = [request.URL.absoluteString stringByReplacingCharactersInRange:range
		                    withString:ips[0]];

		NSMutableURLRequest *newRequest = [request mutableCopy];
		newRequest.URL = [[NSURL alloc] initWithString:newURL];
		[newRequest setValue:host forHTTPHeaderField:@"Host"];
		request = newRequest;

	} else {
		setStat(_stats, @"ip", host);

	}

	return request;
}

- (NSURLSessionDownloadTask *) generateDownloadTask:(NSURLRequest *)request {

	NSURLRequest *newRequest = [self newRequest:request];
	if (newRequest == nil) {
		newRequest = request;
	}

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];

	return [session downloadTaskWithRequest:request];
}


- (void) cancel {
	[_lock lock];
	if (_taskStat != TaskNormal) {
		_expectedAction = TaskCancel;
		[_lock unlock];
		return;
	}
	[_lock unlock];

	[_realTask cancel];
}
- (void) resume {

	[_lock lock];

	if (_taskStat == TaskFailed || _taskStat == TaskGenerating) {
		// 如果是 之前运行过resume失败，或者是resume正在产生task，这时候不执行就可以；
		[_lock unlock];
		return;
	}

	if (_taskStat == TaskNormal) {
		[_lock unlock];
		// 曾经suspend过的记录有问题，不上报
		[_stats setObject:[NSNumber numberWithBool:true] forKey:@"invalid"];
		[_realTask resume];
		return;
	}

	// TaskNotStarted
	_taskStat = TaskGenerating;
	[_lock unlock];


	QNAsyncRun(^{

		// 产生task的过程中会需要去查询DNS，所以用异步操作
		_realTask = [self generateDownloadTask:_oldRequest];

#if TARGET_OS_IPHONE
		if (_manager.statsManager.reachabilityStatus == ReachableViaWiFi) {
		        [_stats setObject:@"wifi" forKey:@"net"];
		} else if (_manager.statsManager.reachabilityStatus == ReachableViaWWAN) {
		        [_stats setObject:@"wan" forKey:@"net"];
		}
#elif TARGET_OS_MAC
		[_stats setObject:@"wifi" forKey:@"net"];
#endif

		[_lock lock];

		// 首先设置产生task的状态： 失败或者成功
		if (_realTask == nil) {
		        _taskStat = TaskFailed;
		        [_lock unlock];
		        return;
		}
		_taskStat = TaskNormal;

		// task 产生成功之后，需要判断在产生期间外部是否设置了动作
		if (_expectedAction == TaskCancel) {
		        [_lock unlock];
		        [_realTask cancel];
		        return;
		}
		if (_expectedAction == TaskSuspend) {
		        [_lock unlock];
		        return;
		}

		// 首次启动的时候记录启动时间，中间如果有暂停或者取消，那么本次的记录值可以作废，因为开始时间已经不对了
		// 不过实际上可以通过progress拿到suspend或者cancel时下载好的部分数据，但是部分数据是准的吗？
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		[_stats setObject: [NSNumber numberWithLongLong:(long long)(now*1000000000)] forKey:@"st"];

		[_lock unlock];

		[_realTask resume];
	});

}
- (void) suspend {

	[_lock lock];

	if (_taskStat != TaskNormal) {
		_expectedAction = TaskSuspend;
		[_lock unlock];
		return;
	}
	[_lock unlock];

	[_realTask suspend];
}

- (void)        URLSession:(NSURLSession *)session
              downloadTask:(NSURLSessionDownloadTask *)downloadTask
         didResumeAtOffset:(int64_t)fileOffset
        expectedTotalBytes:(int64_t)expectedTotalBytes {

	if (_progress == nil) {
		return;
	}
	_progress.totalUnitCount = expectedTotalBytes;
	_progress.completedUnitCount = fileOffset;
}

- (void)               URLSession:(NSURLSession *)session
                     downloadTask:(NSURLSessionDownloadTask *)downloadTask
                     didWriteData:(int64_t)bytesWritten
                totalBytesWritten:(int64_t)totalBytesWritten
        totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {

	if (_progress == nil) {
		return;
	}

	_progress.totalUnitCount = totalBytesExpectedToWrite;
	_progress.completedUnitCount = totalBytesWritten;

}

- (void)               URLSession:(NSURLSession *)session
                     downloadTask:(NSURLSessionDownloadTask *)downloadTask
        didFinishDownloadingToURL:(NSURL *)location {

	if (![_stats objectForKey:@"invalid"]) {
		// update stats

		// 记录本地出口IP
		setStat(_stats, @"sip", _manager.statsManager.sip);


		// costed time
		long long now = (long long)([[NSDate date] timeIntervalSince1970]* 1000000000);
		long long st = [[_stats valueForKey:@"st"] longLongValue];
		NSNumber *td = [NSNumber numberWithLongLong:(now - st)/1000000];
		setStat(_stats, @"td", td);

		// size
		if (downloadTask.response != nil) {
			NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)downloadTask.response;
			[_stats setObject:[NSNumber numberWithInteger:[httpResponse statusCode]] forKey:@"code"];

			// ok 用于设定访问是否成功（未写到文档里面
			[_stats setObject:@"1" forKey:@"ok"];

			if ([httpResponse statusCode]/100 == 2) {
				if (httpResponse.expectedContentLength != NSURLResponseUnknownLength) {
					[_stats setObject:[NSNumber numberWithLongLong:httpResponse.expectedContentLength] forKey:@"bd"];
				} else {
					NSNumber *fileSizeValue = nil;

					[location getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:nil];
					if (fileSizeValue) {
						[_stats setObject:fileSizeValue forKey:@"bd"];
					}
				}
			}

		} else {
			[_stats setObject:@"0" forKey:@"ok"];
		}

		//NSLog(@"stats: %@", _stats);
		[_manager.statsManager addStatics:_stats];
	} else {
		// 非法的数据不上报
	}

	// mv to expected location and call completionHandler
	NSURL *mvDestination = location;
	if (_destination) {
		NSError *fileManagerError = nil;
		mvDestination = _destination(location, downloadTask.response);
		if (mvDestination) {
			[[NSFileManager defaultManager] moveItemAtPath:location toPath:mvDestination error:&fileManagerError];

			if (fileManagerError) {
				_completionHandler(downloadTask.response, mvDestination, fileManagerError);

				return;
			}
		}
	}
	_completionHandler(downloadTask.response, mvDestination, nil);
}

#endif

@end

