//
//  QNDns.m
//  QiniuSDK
//
//  Created by bailong on 15/1/2.
//  Copyright (c) 2015年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <arpa/inet.h>

#import "QNDns.h"

@implementation QNDns

+ (NSArray *)getAddresses:(NSString *)hostName {
	CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostName);

	Boolean lookup = CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL);
	NSArray *addresses = (__bridge NSArray *)CFHostGetAddressing(hostRef, &lookup);
	__block NSMutableArray *ret = [[NSMutableArray alloc] init];
	[addresses enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
	    struct in_addr *data = (__bridge struct in_addr *)obj;
	    char buf[32];
	    const char *p = inet_ntop(AF_INET, (void *)data, buf, 32);
	    NSString *ip = [NSString stringWithUTF8String:p];
	    [ret addObject:ip];
//        NSLog(@"Resolved %lu->%@", (unsigned long)idx, ip);
	}];
	return ret;
}

+ (NSString *)getAddressesString:(NSString *)hostName {
	NSArray *result = [QNDns getAddresses:hostName];
	if (result.count == 0) {
		return @"";
	}
	return [result componentsJoinedByString:@";"];
}

@end
