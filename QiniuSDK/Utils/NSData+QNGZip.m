//
//  NSData+QNGZip.m
//  GZipTest
//
//  Created by yangsen on 2020/8/12.
//  Copyright © 2020 yangsen. All rights reserved.
//

#import "NSData+QNGZip.h"
#import <zlib.h>

#pragma clang diagnostic ignored "-Wcast-qual"

@implementation NSData(QNGZip)

- (NSData *)qn_gZip{
    
    if (self.length == 0 || [self qn_isGzippedData]){
        return self;
    }

    z_stream stream;
    stream.opaque = Z_NULL;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.total_out = 0;
    stream.avail_out = 0;
    stream.avail_in = (uint)self.length;
    stream.next_in = (Bytef *)(void *)self.bytes;

    static const NSUInteger chunkSize = 16384;

    NSMutableData *gzippedData = nil;
    
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK) {
        gzippedData = [NSMutableData dataWithLength:chunkSize];
        while (stream.avail_out == 0) {
            if (stream.total_out >= gzippedData.length) {
                gzippedData.length += chunkSize;
            }
            stream.next_out = (uint8_t *)gzippedData.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(gzippedData.length - stream.total_out);
            deflate(&stream, Z_FINISH);
        }
        deflateEnd(&stream);
        gzippedData.length = stream.total_out;
    }

    return gzippedData;
}

- (NSData *)qn_gUnzip{
    if (self.length == 0 || ![self qn_isGzippedData]){
        return self;
    }

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.total_out = 0;
    stream.avail_out = 0;
    stream.avail_in = (uint)self.length;
    stream.next_in = (Bytef *)self.bytes;

    NSMutableData *gunzippedData = nil;
    if (inflateInit2(&stream, 47) == Z_OK) {
        int status = Z_OK;
        gunzippedData = [NSMutableData dataWithCapacity:self.length * 2];
        while (status == Z_OK) {
            if (stream.total_out >= gunzippedData.length) {
                gunzippedData.length += self.length / 2;
            }
            stream.next_out = (uint8_t *)gunzippedData.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(gunzippedData.length - stream.total_out);
            status = inflate (&stream, Z_SYNC_FLUSH);
        }
        if (inflateEnd(&stream) == Z_OK) {
            if (status == Z_STREAM_END) {
                gunzippedData.length = stream.total_out;
            }
        }
    }

    return gunzippedData;
}

- (BOOL)qn_isGzippedData{
    const UInt8 *bytes = (const UInt8 *)self.bytes;
    return (self.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
}

@end
