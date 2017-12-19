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
    
    PFRelation * friendsRelation = [[PFUser currentUser] relationForKey:@"friends"];
    PFQuery * query = [friendsRelation query] ;
    query.cachePolicy = kPFCachePolicyCacheThenNetwork;
    
    NSMutableArray<TLUser*> *friends = [NSMutableArray array];
    
    if (isLoadingData) {
        return;
    }
    isLoadingData = YES;
    [[friendsRelation query] findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
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
            model.nikeName = nickName;
            
      
            if (user[@"headerImage1"] && user[@"headerImage1"] != [NSNull null]) {
                PFFile * file = user[@"headerImage1"];
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
    
    dispatch_group_t serviceGroup = dispatch_group_create();
    

    __block NSInteger i = 0;
    for (TLUser * friend in [TLFriendHelper sharedFriendHelper].friendsData) {
        
        dispatch_group_enter(serviceGroup);
        i = i + 1;
        DLog(@"group items %ld", (long)i);
        [self createFriendDialogWithLatestMessage:friend completionBlock:^{
        
            DLog(@"friend.userID %@", friend.userID);
            NSString * key = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:friend.userID myId:[PFUser currentUser].objectId];
            
            TLConversation * conversation = [[TLMessageManager sharedInstance].conversationStore conversationByKey:key];
            if (conversation) {
                [[TLMessageManager sharedInstance].conversationStore countUnreadMessages:conversation withCompletionBlock:^{
                    
                    dispatch_group_leave(serviceGroup);
                    i = i - 1;
                    DLog(@"group items %ld", (long)i);
                }];
            }else{
                DLog(@"no converstation for friend: %@", friend.userID);
                
                dispatch_group_leave(serviceGroup);
                
                i = i - 1;
                DLog(@"group items %ld", (long)i);
            }
            
            
        }];
        

        
    }
    
    dispatch_group_notify(serviceGroup, dispatch_get_main_queue(), ^{
        
        if (completionBlock) {
            completionBlock();
            NSLog(@"recreateLocalDialogsForFriendsWithCompletionBlock done");
        }
        
    });
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
                                                                                localOnly:YES];
                
            }else{
                if (localDeleteDate) {
                }else{
                    [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                          fid:friend.userID
                                                                                         type:TLConversationTypePersonal
                                                                                         date:friend.date
                                                                                 last_message:@"Let's start chat"
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
