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
//#import "TLAppDelegate.h"
#import "TLMacros.h"

@implementation TLFriendDataLoader {
 
}

static TLFriendDataLoader *friendDataLoader = nil;

static BOOL isLoadingData = NO;

+ (TLFriendDataLoader *)sharedFriendDataLoader {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        friendDataLoader = [[TLFriendDataLoader alloc] init];
    });
    return friendDataLoader;
}

- (void)p_loadFriendsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *friends))completionBlock {
    
  
    PFQuery * query = [PFUser query] ;
    query.cachePolicy = kPFCachePolicyCacheThenNetwork;
    
    NSMutableArray<TLUser*> *friends = [NSMutableArray array];
    
    if (isLoadingData) {
        return;
    }
    isLoadingData = YES;
    
    NSString *path = [[NSBundle mainBundle] pathForResource: @"TLChat" ofType: @"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
    
    NSString * nicknameKey = [dict objectForKey:@"TLChatUserNickNameFieldName"];
    NSString * nicknameFieldName = nicknameKey ?: kParseUserClassAttributeNickname;
    
    NSString * avatarKey = [dict objectForKey:@"TLChatUserAvatarFieldName"];
    NSString * avatarFieldName = avatarKey ?: kParseUserClassAttributeAvatar;
    
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        isLoadingData = NO;
        
        
        NSLog(@"fetched %lu friends from server", objects.count);
        
        for (PFUser * user in objects) {
            TLUser * model = [TLUser new];
            model.userID = user.objectId;
      
            NSString * nickName = [user.username stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]];
            NSError *error = nil;
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"  +" options:NSRegularExpressionCaseInsensitive error:&error];
            nickName = [regex stringByReplacingMatchesInString:nickName options:0 range:NSMakeRange(0, [nickName length]) withTemplate:@" "];
   
            model.username = nickName;
            model.nikeName = [nicknameFieldName isEqualToString:@"username"] ? user.username : user[nicknameFieldName];
            
      
            if (user[avatarFieldName] && user[avatarFieldName] != [NSNull null]) {
                PFFile * file = user[avatarFieldName];
                model.avatarURL = file.url;
            }
            model.date = user.updatedAt;
            
            [friends addObject:model];
            
  
            
        }
        
        if (completionBlock) {
            completionBlock(friends);
        }
        
    }];
}

- (void)recreateLocalDialogsForFriendsWithCompletionBlock:(void(^)())completionBlock {
    

    

    __block NSInteger i = 0;
//    for (TLUser * friend in [TLFriendHelper sharedFriendHelper].friendsData)
    PFQuery * query = [PFQuery queryWithClassName:kParseClassNameDialog];
//    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query whereKey:@"key" containsString:[PFUser currentUser].objectId];
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        dispatch_group_t serviceGroup = dispatch_group_create();
        
        for (PFObject * object in objects) {
            NSArray * userIds = [object[@"key"] componentsSeparatedByString:@":"];
            if ([userIds count] > 0 ) {
                NSArray * matches = [userIds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@", [PFUser currentUser].objectId]];
                if (matches.count > 0) {
                    NSString * friendId = matches.firstObject;
                    
                    TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:friendId];
                    
                    {
                        
                        dispatch_group_enter(serviceGroup);
                        i = i + 1;
                        DLog(@"friends items %ld", (long)i);
                        [self createFriendDialogWithLatestMessage:friend completionBlock:^{
                            
                            DLog(@"friend.userID %@", friend.userID);
                            NSString * key = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:friend.userID myId:[PFUser currentUser].objectId];
                            
                            TLConversation * conversation = [[TLMessageManager sharedInstance].conversationStore conversationByKey:key];
                            if (conversation) {
                                [[TLMessageManager sharedInstance].conversationStore countUnreadMessages:conversation withCompletionBlock:^(NSInteger count) {
                                    
                                    
                                    dispatch_group_leave(serviceGroup);
                                    i = i - 1;
                                    DLog(@"friends items %ld", (long)i);
                                    DLog(@"friends item %@ unreadmessages: %ld", conversation.key, (long)count);
                                }];
                            }else{
                                DLog(@"no converstation for friend: %@", friend.userID);
                                
                                dispatch_group_leave(serviceGroup);
                                
                                i = i - 1;
                                DLog(@"friends items %ld", (long)i);
                            }
                            
                            
                        }];
                        
                        
                        
                    }
                }
            }
        }
        
        
        dispatch_group_notify(serviceGroup, dispatch_get_main_queue(), ^{
            
            if (completionBlock) {
                completionBlock();
                NSLog(@"recreateLocalDialogsForFriendsWithCompletionBlock done");
            }
            
        });
        
    }];
    
    
    

}

- (void)createFriendDialogWithLatestMessage:(TLUser *)friend completionBlock:(void(^)())completionBlock
{
    NSString * key = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:friend.userID myId:[PFUser currentUser].objectId];
    
    PFQuery * dialogQuery = [PFQuery queryWithClassName:kParseClassNameDialog];
    [dialogQuery whereKey:@"key" equalTo:key];
    [dialogQuery whereKey:@"user" equalTo:[PFUser currentUser]];
    [dialogQuery orderByDescending:@"updatedAt"];
    [dialogQuery getFirstObjectInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        
        NSDate * localDeleteDate = nil;
        if (object && object[@"localDeletedAt"]) {
            localDeleteDate = object[@"localDeletedAt"];
        }else{
            
        }
        
        
        PFQuery * query = [PFQuery queryWithClassName:kParseClassNameMessage];
        DLog(@"key %@", key);
        [query whereKey:@"dialogKey" equalTo:key];
        [query orderByDescending:@"createdAt"];
        
        if (localDeleteDate) {
            [query whereKey:@"createdAt" greaterThan:localDeleteDate];
        }
        
        [query getFirstObjectInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
            
            if (object) {
                [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                      fid:friend.userID
                                                                                     type:TLConversationTypePersonal
                                                                                     date:object.createdAt
                                                                             last_message:[TLMessage conversationContentForMessage: object[@"message"]]
                                                                     last_message_context:object[@"context"] ?: @""
                                                                                localOnly:YES];
                
            }else{
                if (localDeleteDate) {
                }else{
                    [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                          fid:friend.userID
                                                                                         type:TLConversationTypePersonal
                                                                                         date:friend.date
                                                                                 last_message:@"Let's start chat"
                                                                         last_message_context:object[@"context"] ?: @""
                                                                                    localOnly:YES];
                };
            }
            
            if (completionBlock) {
                completionBlock();
            }
           

        }];
    }];
}

@end
