//
//  TLUIManager.m
//  UNI
//
//  Created by Frank Mao on 2017-12-14.
//  Copyright © 2017 Mazoic Technologies Inc. All rights reserved.
//

#import "TLUIManager.h"
#import "TLChatViewController.h"
#import "TLFriendDetailViewController.h"

@implementation TLUIManager

static TLUIManager *uiManager = nil;

+ (TLUIManager *)sharedUIManager
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        uiManager = [[TLUIManager alloc] init];
    });
    return uiManager;
}


- (void)openChatDialog:(NSString *)dialogKey {
    
    UINavigationController * containerVC = (UINavigationController*)[UIApplication sharedApplication].delegate.window.rootViewController;
//    MMDrawerController * mainDrawer = (MMDrawerController *)containerVC.viewControllers.firstObject;
//    UITabBarController * tabbarVC = (UITabBarController *)mainDrawer.centerViewController;
    UITabBarController * tabbarVC = (UITabBarController *)containerVC;
    tabbarVC.selectedIndex = 1;

    UINavigationController * nVC = (UINavigationController*) tabbarVC.viewControllers[0];
    
    
    TLChatViewController * chatVC = [nVC findViewController:@"TLChatViewController"];
    if (chatVC) {
        if ([dialogKey isEqualToString:chatVC.conversationKey]) {
            [nVC popToViewControllerWithClassName:@"TLChatViewController" animated:YES];
            return;
        }
        
    }
    
    TLChatViewController * vc = [TLChatViewController new];
    
    vc.conversationKey = dialogKey;
    
    [nVC pushViewController:vc animated:YES];
 
}

- (void)openUserDetails:(TLUser *)user navigationController:(UINavigationController*)navigationController {
    
    TLFriendDetailViewController *detailVC = [[TLFriendDetailViewController alloc] init];
    [detailVC setUser:user];
    [detailVC setHidesBottomBarWhenPushed:YES];
    [navigationController pushViewController:detailVC animated:YES];
}

@end
