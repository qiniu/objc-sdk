//
//  QNCFHttpClientTest.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNCFHttpClient.h"
#import "NSURLRequest+QNRequest.h"
#import "QNTestConfig.h"
#import <XCTest/XCTest.h>
#import "XCTestCase+QNTest.h"

@interface QNCFHttpClientTest : XCTestCase

@property(nonatomic, strong)QNCFHttpClient *client;

@end
@implementation QNCFHttpClientTest

- (void)setUp {
    
}

- (void)tearDown {
    [super tearDown];
    
    self.client = nil;
}

- (void)testHttpGet{
    NSString *urlString = @"http://uc.qbox.me/v3/query?ak=jH983zIUFIP1OVumiBVGeAfiLYJvwrF45S-t22eu&bucket=zone0-space";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self request:request];
}

- (void)testHttpsGet{
    NSURL *url = [NSURL URLWithString:@"https://uc.qbox.me/v3/query?ak=jH983zIUFIP1OVumiBVGeAfiLYJvwrF45S-t22eu&bucket=zone0-space"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self request:request];
}

- (void)testHttpGetByIP{
    NSURL *url = [NSURL URLWithString:@"http://218.98.28.19/v3/query?ak=jH983zIUFIP1OVumiBVGeAfiLYJvwrF45S-t22eu&bucket=zone0-space"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.qn_domain = @"uc.qbox.me";
    
    [self request:request];
}

- (void)testHttpsGetByIP{
    NSURL *url = [NSURL URLWithString:@"https://218.98.28.19/v3/query?ak=jH983zIUFIP1OVumiBVGeAfiLYJvwrF45S-t22eu&bucket=zone0-space"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.qn_domain = @"uc.qbox.me";
    
    [self request:request];
}

- (void)testHttpPost{
    
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"http://up-na0.qiniup.com"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}

- (void)testHttpsPost{
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"https://up-na0.qiniup.com"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}

- (void)testHttpPostByIP{
    
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"http://23.236.102.2"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}

- (void)testHttpsPostByIP{
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"https://23.236.102.2"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}


- (NSURLRequest *)postRequest:(NSString *)urlstring
                       domain:(NSString *)domain
                        param:(NSDictionary *)params
                         body:(NSData *)data{
    
    NSURL *url = [NSURL URLWithString:urlstring];
    NSMutableData *body = [NSMutableData data];
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    for (NSString *paramsKey in params) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n", boundary, paramsKey];
        [body appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

        id value = [params objectForKey:paramsKey];
        if ([value isKindOfClass:[NSString class]]) {
            [body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSData class]]) {
            [body appendData:value];
        }
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"?\"\nContent-Type:text/plain\r\n\r\n", boundary];
    [body appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.qn_domain  = domain;
    request.HTTPMethod = @"POST";
    request.HTTPBody   = [body copy];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    NSString *contentLength = [NSString stringWithFormat:@"%ld", (long)[body length]];
    request.allHTTPHeaderFields = @{@"Content-Type" : contentType,
                                    @"Content-Length" : contentLength};
    return [request copy];
}

//MARK: --
- (void)request:(NSURLRequest *)request{
    self.client = [[QNCFHttpClient alloc] init];
    [self.client request:request server:nil connectionProxy:@{@"HTTPSProxy":@"aaa", @"HTTPSPort":@80} progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        NSLog(@"progress written:%lld total:%lld", totalBytesWritten, totalBytesExpectedToWrite);
    } complete:^(NSURLResponse * _Nullable response, QNUploadSingleRequestMetrics * _Nullable metrics, NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            XCTAssertTrue(error == nil, "error:%@", error);
        }
        
        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"responseString:%@", responseString);
        XCTAssertTrue([(NSHTTPURLResponse * )response statusCode] == 200, "response:%@", response);
        QN_TEST_CASE_CONTINUE
    }];
    QN_TEST_CASE_WAIT
}


@end
