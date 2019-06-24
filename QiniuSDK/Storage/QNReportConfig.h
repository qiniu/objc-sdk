//
//  QNReportConfig.h
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2019/6/24.
//  Copyright © 2019 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNReportConfig : NSObject

@property (nonatomic, copy, readonly) NSString *serverURL;

@property (nonatomic, copy, readonly) NSString *recordDirectory;

@property (nonatomic, assign, getter=isRecordEnable) BOOL recordEnable;

@property (nonatomic, assign) long maxRecordFileSize;

@property (nonatomic, assign) long uploadThreshold;

@property (nonatomic, assign) int interval;

@end
