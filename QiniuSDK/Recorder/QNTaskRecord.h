//
//  QNTaskRecord.h
//  QiniuSDK
//
//  Created by chen on 15/9/17.
//  Copyright © 2015年. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNTaskRecord : NSObject

@property (nonatomic, assign) int blockIndex;
@property (nonatomic, assign) UInt32 offset;
@property (nonatomic, assign, getter=isRunning) BOOL running;
@property (nonatomic, copy) NSString *context;
@property (nonatomic, assign) UInt32 chunkCrc;

- (BOOL)isFinished;

- (NSDictionary*)jsonFromObj;
+ (QNTaskRecord*)recordFromJson:(NSDictionary*)json;

@end
