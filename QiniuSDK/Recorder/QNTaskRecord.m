//
//  QNTaskRecord.m
//  QiniuSDK
//
//  Created by chen on 15/9/17.
//  Copyright © 2015年. All rights reserved.
//

#import "QNTaskRecord.h"
#import "QNConfiguration.h"

@implementation QNTaskRecord

- (BOOL)isFinished
{
    return (self.blockIndex + 1) * kQNBlockSize == self.offset;
}

- (NSDictionary *)jsonFromObj
{
    return @{@"blockIndex" : @(self.blockIndex),
             @"offset" : @(self.offset),
             @"running" : @(self.isRunning),
             @"context" : self.context ? self.context : @""};
}

+ (QNTaskRecord *)recordFromJson:(NSDictionary *)json
{
    if ([json isKindOfClass:[NSDictionary class]] == NO) {
        return nil;
    }
    
    QNTaskRecord *record = [[QNTaskRecord alloc] init];
    record.blockIndex = [json[@"blockIndex"] intValue];
    record.offset = [json[@"offset"] unsignedIntValue];
    record.running = [json[@"running"] boolValue];
    record.context = json[@"context"];
    return record;
}

@end
