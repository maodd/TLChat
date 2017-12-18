//
//  TLAppDelegate.m
//  TLChat
//
//  Created by 李伯坤 on 16/1/23.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLAppDelegate.h"
#import "TLLaunchManager.h"
#import "TLSDKManager.h"
#import <Parse/Parse.h>

@implementation TLAppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    // 初始化第三方SDK
//    [[TLSDKManager sharedInstance] launchInWindow:self.window];
    [Parse initializeWithConfiguration:[ParseClientConfiguration configurationWithBlock:^(id<ParseMutableClientConfiguration> configuration) {
        configuration.applicationId = kParseAPPID;
        configuration.clientKey = kParseCleintKey;
        configuration.server =  kParseServer;
        configuration.localDatastoreEnabled = NO; // If you need to enable local data store
    }]];
    
    // 初始化UI
    [[TLLaunchManager sharedInstance] launchInWindow:self.window];
    
    // 紧急方法，可使用JSPatch重写
    [self urgentMethod];
    
    
 
    return YES;
}

- (void)urgentMethod
{

}

 

@end
