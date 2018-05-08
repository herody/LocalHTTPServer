//
//  ViewController.m
//  LocalHTTPServer
//
//  Created by 侯亚迪 on 2018/1/28.
//  Copyright © 2017年 侯亚迪. All rights reserved.
//

#import "ViewController.h"
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "YDHTTPConnection.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_WARN;

@interface ViewController ()
{
    HTTPServer *httpServer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self startServer];
}


- (void)startServer
{
    // Configure our logging framework.
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    // Initalize our http server
    httpServer = [[HTTPServer alloc] init];
    
    // Tell the server to broadcast its presence via Bonjour.
    [httpServer setType:@"_http._tcp."];
    
    // Normally there's no need to run our server on any specific port.
    [httpServer setPort:12345];
    
    // We're going to extend the base HTTPConnection class with our MyHTTPConnection class.
    [httpServer setConnectionClass:[YDHTTPConnection class]];
    
    // Serve files from our embedded Web folder
    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    DDLogInfo(@"Setting document root: %@", webPath);
    [httpServer setDocumentRoot:webPath];
    
    NSError *error = nil;
    if(![httpServer start:&error])
    {
        DDLogError(@"Error starting HTTP Server: %@", error);
    }
}


@end
