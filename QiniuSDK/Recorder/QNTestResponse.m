//
//  QNTestResponse.m
//  QiniuSDK
//
//  Created by WorkSpace_Sun on 2020/4/3.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNTestResponse.h"

@implementation QNTestResponse
+ (NSDictionary *)getResponse {
    NSMutableArray *hosts = [NSMutableArray array];
    NSDictionary *host1 = @{
        @"api" : @{
                @"acc" : @{
                        @"main" : @[@"api.qiniu.com"]
                }
        },
        @"io" : @{
                @"src" : @{
                        @"main" : @[@"iovip.qbox.me"]
                }
        },
        @"rs" : @{
                @"acc" : @{
                        @"main" : @[@"rs-z0.qbox.me"]
                }
        },
        @"rsf" : @{
                @"acc" : @{
                        @"main" : @[@"rsf-z0.qbox.me"]
                }
        },
        @"ttl" : @86400,
        @"uc" : @{
                @"acc" : @{
                        @"main" : @[@"uc.qbox.me"]
                }
        },
        @"up" : @{
                @"acc" : @{
                        @"main" : @[@"1-up-acc-main"],
                        @"backup" : @[@"1-up.acc.backup1", @"1-up-acc-backup2"]
                },
                @"old_acc" : @{
                        @"main" : @[@"1-up-old_acc-main"],
                        @"info" : @"compatible to non-SNI device"
                },
                @"old_src" : @{
                        @"main" : @[@"1-up-old_src-main"],
                        @"info" : @"compatible to non-SNI device"
                },
                @"src" : @{
                        @"main" : @[@"1-up-src-main"],
                        @"backup" : @[@"1-up-src-backup1", @"1-up-src-backup2"]
                }
        }
    };
    NSDictionary *host2 = @{
        @"api" : @{
                @"acc" : @{
                        @"main" : @[@"api.qiniu.com"]
                }
        },
        @"io" : @{
                @"src" : @{
                        @"main" : @[@"iovip-z2.qbox.me"]
                }
        },
        @"rs" : @{
                @"acc" : @{
                        @"main" : @[@"rs-z2.qbox.me"]
                }
        },
        @"rsf" : @{
                @"acc" : @{
                        @"main" : @[@"rsf-z2.qbox.me"]
                }
        },
        @"ttl" : @86400,
        @"uc" : @{
                @"acc" : @{
                        @"main" : @[@"uc.qbox.me"]
                }
        },
        @"up" : @{
                @"acc" : @{
                        @"main" : @[@"2-up-acc-main"],
                        @"backup" : @[@"upload-z2.qiniup.com", @"2-up-acc-backup2"]
                },
                @"old_acc" : @{
                        @"main" : @[@"2-up-old_acc-main"],
                        @"info" : @"compatible to non-SNI device"
                },
                @"old_src" : @{
                        @"main" : @[@"2-up-old_src-main"],
                        @"info" : @"compatible to non-SNI device"
                },
                @"src" : @{
                        @"main" : @[@"2-up-src-main"],
                        @"backup" : @[@"2-up-src-backup1", @"2-up-src-backup2"]
                }
        }
    };
    [hosts addObject:host1];
    [hosts addObject:host2];
    return @{@"hosts" : hosts};
}
@end
