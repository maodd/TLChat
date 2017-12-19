//
//  TLUIManager.h
//  UNI
//
//  Created by Frank Mao on 2017-12-14.
//  Copyright © 2017 Mazoic Technologies Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TLKit/TLKit.h>

@class TLUser;

@interface TLUIManager : NSObject
+ (TLUIManager *)sharedUIManager;

- (void)openChatDialog:(NSString *)dialogKey;
- (void)openUserDetails:(TLUser *)user navigationController:(UINavigationController*)navigationController;

@end
