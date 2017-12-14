//
//  TLUIManager.m
//  UNI
//
//  Created by Frank Mao on 2017-12-14.
//  Copyright © 2017 Mazoic Technologies Inc. All rights reserved.
//

#import "TLUIManager.h"
#import "TLChatViewController.h"

@implementation TLUIManager

- (void)openChatDialog:(NSString *)dialogKey {
    
    UINavigationController * containerVC = (UINavigationController*)[UIApplication sharedApplication].delegate.window.rootViewController;
    MMDrawerController * mainDrawer = (MMDrawerController *)containerVC.viewControllers.firstObject;
    UITabBarController * tabbarVC = (UITabBarController *)mainDrawer.centerViewController;
    tabbarVC.selectedIndex = 1;
    
    UINavigationController * nVC = (UINavigationController*) tabbarVC.viewControllers[1];
    
    
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

@end
