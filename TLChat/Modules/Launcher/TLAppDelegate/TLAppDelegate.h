//
//  TLAppDelegate.h
//  TLChat
//
//  Created by 李伯坤 on 16/1/23.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const kAKUserLoggedInNotification;
extern NSString * const kAKFriendsDataUpdateNotification;

@interface TLAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
