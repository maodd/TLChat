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
#import "TLFriendHelper.h"

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

- (void)openChatDialogWithUser:(NSString *)userId fromNavigationController:(UINavigationController *)navigationController  context:(NSString*)context {
    TLChatViewController * chatVC = [navigationController findViewController:@"TLChatViewController"];
    if (chatVC) {
        if ([userId isEqualToString:[chatVC.partner chat_userID]]) {
            chatVC.title = context;
            [navigationController popToViewControllerWithClassName:@"TLChatViewController" animated:YES];
            return;
        }
        
    }
    
    TLChatViewController * vc = [TLChatViewController new];
    TLUser * partner = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:userId];
    vc.partner = (id<TLChatUserProtocol>)partner;
    vc.title = context;
    [navigationController pushViewController:vc animated:YES];
}

- (void)openChatDialog:(NSString *)dialogKey navigationController:(UINavigationController*)navigationController{
    
    UIViewController * rootVC = [[UIApplication sharedApplication].delegate window].rootViewController;
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
    
        UITabBarController * tabVC = (UITabBarController*)rootVC;
    
        for (UIViewController * vc in tabVC.viewControllers) {
            if ([vc isKindOfClass:[UINavigationController class]]) {
                TLChatViewController * chatVC = [navigationController findViewController:@"TLChatViewController"];
                if (chatVC) {
                    if ([dialogKey isEqualToString:chatVC.conversationKey]) {
                        
                        [(UINavigationController*)vc popToViewControllerWithClassName:@"TLChatViewController" animated:YES];
                        
                        tabVC.selectedIndex = [tabVC.viewControllers indexOfObject:vc];
                        return;
                    }
                    
                }
            }
        }
    }
    
    [self handleOpenChatDialog:dialogKey navigationController:navigationController];
   

}

- (void)handleOpenChatDialog:(NSString *)dialogKey navigationController:(UINavigationController*)navigationController {
    TLChatViewController * chatVC = [navigationController findViewController:@"TLChatViewController"];
    if (chatVC) {
        if ([dialogKey isEqualToString:chatVC.conversationKey]) {
            
            [navigationController popToViewControllerWithClassName:@"TLChatViewController" animated:YES];
            return;
        }
        
    }
    
    TLChatViewController * vc = [TLChatViewController new];
    
    vc.conversationKey = dialogKey;
    
    [navigationController pushViewController:vc animated:YES];
}

- (void)openUserDetails:(TLUser *)user navigationController:(UINavigationController*)navigationController {

    // TODO: find better way to allow app use different style to open user details.
    
    TLFriendDetailViewController *detailVC = [[TLFriendDetailViewController alloc] init];
    [detailVC setUser:user];
    [detailVC setHidesBottomBarWhenPushed:YES];
    [navigationController pushViewController:detailVC animated:YES];
}

@end
