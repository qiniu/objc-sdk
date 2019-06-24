//
//  QNReportConfig.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNReportConfig : NSObject

@property (nonatomic, assign, getter=isRecordEnable) BOOL recordEnable;

@property (nonatomic, assign) int interval;

@property (nonatomic, copy, readonly) NSString *serverURL;

@property (nonatomic, copy, readonly) NSString *recordDirectory;

@property (nonatomic, assign, readonly) int64_t maxRecordFileSize;

@property (nonatomic, assign, readonly) int64_t uploadThreshold;

@property (nonatomic, assign, readonly) UInt32 timeoutInterval;

@end
