//
//  TLFriendDataLoader.m
//  TLChat
//
//  Created by Frank Mao on 2017-12-05.
//  Copyright © 2017 李伯坤. All rights reserved.
//

#import "TLFriendDataLoader.h"
#import <Parse/Parse.h>
#import "TLFriendHelper.h"
#import "TLMessageManager.h"
#import "TLConversation.h"
#import "TLMessage.h"
#import "TLAppDelegate.h"

@implementation TLFriendDataLoader

+ (void)p_loadFriendsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *friends))completionBlock {
    
    PFRelation * friendsRelation = [[PFUser currentUser] relationForKey:@"friends"];
    PFQuery * query = [friendsRelation query] ;
    query.cachePolicy = kPFCachePolicyCacheThenNetwork;
    
    NSMutableArray<TLUser*> *friends = [NSMutableArray array];
    
    [[friendsRelation query] findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        [friends removeAllObjects];
        
        NSLog(@"fetched %u friends from server", objects.count);
        
        for (PFUser * user in objects) {
            TLUser * model = [TLUser new];
            model.userID = user.objectId;
            model.nikeName = [user.username stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (user[@"headerImage1"] && user[@"headerImage1"] != [NSNull null]) {
                PFFile * file = user[@"headerImage1"];
                model.avatarURL = file.url;
            }
            
            [friends addObject:model];
            
  
            
        }
        
        if (completionBlock) {
            completionBlock(friends);
        }
        
    }];
}

+ (void)recreateLocalDialogsForFriends {
    for (TLUser * friend in [TLFriendHelper sharedFriendHelper].friendsData) {
        [self createFriendDialogWithLatestMessage:friend];
    }
}

+ (void)createFriendDialogWithLatestMessage:(TLUser *)friend
{
    NSString * key = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:friend.userID myId:[PFUser currentUser].objectId];
    PFQuery * query = [PFQuery queryWithClassName:kParseClassNameMessage];
    [query whereKey:@"dialogKey" equalTo:key];
    [query orderByDescending:@"createdAt"];
    
    [query getFirstObjectInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        
        if (object) {
            [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                  fid:friend.userID
                                                                                 type:TLConversationTypePersonal
                                                                                 date:object.createdAt
                                                                         last_message:[TLMessage conversationContentForMessage: object[@"message"]]
                                                                            localOnly:YES];
        }else{
            [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                  fid:friend.userID
                                                                                 type:TLConversationTypePersonal
                                                                                 date:[NSDate date]
                                                                         last_message:@"Let's start chat"
                                                                            localOnly:YES];
        }
       
        [[NSNotificationCenter defaultCenter] postNotificationName:kAKFriendsDataUpdateNotification object:nil];
    }];
}

@end
