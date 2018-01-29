//
//  TLConversationViewController.h
//  TLChat
//
//  Created by 李伯坤 on 16/1/23.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLTableViewController.h"
#import "TLMessageManager+ConversationRecord.h"
#import "TLFriendSearchViewController.h"
@import Parse;
@import ParseLiveQuery;
@import Parse.PFQuery;

@interface TLConversationViewController : TLTableViewController {
    NSArray * _currentKeys;
}

@property (nonatomic, strong) TLFriendSearchViewController *searchVC;

@property (nonatomic, strong) NSMutableArray *data;


@property (nonatomic, strong) PFLiveQueryClient *client;
@property (nonatomic, strong) PFLiveQueryClient *client1;
@property (nonatomic, strong) PFQuery *query;
@property (nonatomic, strong) PFQuery *query1;
@property (nonatomic, strong) PFLiveQuerySubscription *subscription; // must use property to hold reference.
@property (nonatomic, strong) PFLiveQuerySubscription *subscription1; // for group chat

- (void)p_initLiveQuery;

@end
