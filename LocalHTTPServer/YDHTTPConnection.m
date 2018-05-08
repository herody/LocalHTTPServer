//
//  KELocalServer.m
//  Kitty
//
//  Created by 侯亚迪 on 2017/10/30.
//  Copyright © 2017年 侯亚迪. All rights reserved.
//

#import "YDHTTPConnection.h"
#import "HTTPMessage.h"
#import "HTTPDataResponse.h"
#import "DDNumber.h"
#import "HTTPLogging.h"
#import <AdSupport/ASIdentifierManager.h>

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;


/**
 * All we have to do is override appropriate methods in HTTPConnection.
**/

@implementation YDHTTPConnection

#pragma mark - https

- (BOOL)isSecureServer
{
    HTTPLogTrace();

    return NO;
}

- (NSArray *)sslIdentityAndCertificates
{
    HTTPLogTrace();
    
    SecIdentityRef identityRef = NULL;
    SecCertificateRef certificateRef = NULL;
    SecTrustRef trustRef = NULL;
    NSString *thePath = [[NSBundle mainBundle] pathForResource:@"localhost" ofType:@"p12"];
    NSData *PKCS12Data = [[NSData alloc] initWithContentsOfFile:thePath];
    CFDataRef inPKCS12Data = (__bridge CFDataRef)PKCS12Data;
    CFStringRef password = CFSTR("123456");
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { password };
    CFDictionaryRef optionsDictionary = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);

    OSStatus securityError = errSecSuccess;
    securityError =  SecPKCS12Import(inPKCS12Data, optionsDictionary, &items);
    if (securityError == 0) {
        CFDictionaryRef myIdentityAndTrust = CFArrayGetValueAtIndex (items, 0);
        const void *tempIdentity = NULL;
        tempIdentity = CFDictionaryGetValue (myIdentityAndTrust, kSecImportItemIdentity);
        identityRef = (SecIdentityRef)tempIdentity;
        const void *tempTrust = NULL;
        tempTrust = CFDictionaryGetValue (myIdentityAndTrust, kSecImportItemTrust);
        trustRef = (SecTrustRef)tempTrust;
    } else {
        NSLog(@"Failed with error code %d",(int)securityError);
        return nil;
    }

    SecIdentityCopyCertificate(identityRef, &certificateRef);
    NSArray *result = [[NSArray alloc] initWithObjects:(__bridge id)identityRef, (__bridge id)certificateRef, nil];

    return result;
}

#pragma mark - get & post

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Add support for POST
	if ([method isEqualToString:@"POST"])
	{
		if ([path isEqualToString:@"/calculate"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			return YES;
		}
	}
	
	return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Inform HTTP server that we expect a body to accompany a POST request
	if([method isEqualToString:@"POST"]) return YES;
	
	return [super expectsRequestBodyFromMethod:method atPath:path];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	HTTPLogTrace();
	
    //获取token
	if ([path isEqualToString:@"/getIdfa"])
    {
        HTTPLogVerbose(@"%@[%p]: postContentLength: %qu", THIS_FILE, self, requestContentLength);
        NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        NSData *responseData = [idfa dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:responseData];
	}
    //获取任务
    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/calculate"])
    {
        HTTPLogVerbose(@"%@[%p]: postContentLength: %qu", THIS_FILE, self, requestContentLength);
        NSData *requestData = [request body];
        NSDictionary *params = [self getRequestParam:requestData];
        NSInteger firstNum = [params[@"firstNum"] integerValue];
        NSInteger secondNum = [params[@"secondNum"] integerValue];
        NSDictionary *responsDic = @{@"add":@(firstNum + secondNum),
                                     @"sub":@(firstNum - secondNum),
                                     @"mul":@(firstNum * secondNum),
                                     @"div":@(firstNum / secondNum)};
        NSData *responseData = [NSJSONSerialization dataWithJSONObject:responsDic options:0 error:nil];
        return [[HTTPDataResponse alloc] initWithData:responseData];
    }
	
	return [super httpResponseForMethod:method URI:path];
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
	HTTPLogTrace();
	
	// If we supported large uploads,
	// we might use this method to create/open files, allocate memory, etc.
}

- (void)processBodyData:(NSData *)postDataChunk
{
	HTTPLogTrace();
	
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
	BOOL result = [request appendData:postDataChunk];
	if (!result)
	{
		HTTPLogError(@"%@[%p]: %@ - Couldn't append bytes!", THIS_FILE, self, THIS_METHOD);
	}
}

#pragma mark - 私有方法

//获取上行参数
- (NSDictionary *)getRequestParam:(NSData *)rawData
{
    if (!rawData) return nil;
    
    NSString *raw = [[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding];
    NSMutableDictionary *paramDic = [NSMutableDictionary dictionary];
    NSArray *array = [raw componentsSeparatedByString:@"&"];
    for (NSString *string in array) {
        NSArray *arr = [string componentsSeparatedByString:@"="];
        NSString *value = [arr.lastObject stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [paramDic setValue:value forKey:arr.firstObject];
    }
    return [paramDic copy];
}

@end
