//
//  TLGroupDataLoader.m
//  TLChat
//
//  Custom project can rewrite this class to implement own logic.
//
//  Created by Frank Mao on 2017-12-05.
//  Copyright © 2017 李伯坤. All rights reserved.
//

#import "TLGroupDataLoader.h"
#import <Parse/Parse.h>
#import "TLMessageManager.h"
#import "TLConversation.h"
#import "TLMessage.h"
//#import "TLAppDelegate.h"
#import "TLFriendHelper.h"
#import "TLUser.h"
//#import "DefaultPortraitView.h"
#import "TLUserHelper.h"
#import "TLMacros.h"

static TLGroupDataLoader *groupDataLoader = nil;

@implementation TLGroupDataLoader
+ (TLGroupDataLoader *)sharedGroupDataLoader
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        groupDataLoader = [[TLGroupDataLoader alloc] init];
    });
    return groupDataLoader;
}

+ (void)p_loadGroupsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *groups))completionBlock {
    
    PFQuery * query = [PFQuery queryWithClassName:@"Course"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query includeKey:@"term"];
 
    NSMutableArray * groups = [NSMutableArray array];
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        [groups removeAllObjects];
        
        NSLog(@"fetched %lu groups from server", objects.count);
        
        for (PFObject * course in objects) {
            PFObject * term = (PFObject*)course[@"term"];
            NSString * name = [NSString stringWithFormat:@"%@ (%@)", course[@"summary"], term[@"name"]];
            NSString * groupName = [name stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([[groups valueForKeyPath:@"groupName"] containsObject:groupName]) {
                continue;
            }
            
            TLGroup * model = [TLGroup new];
            model.groupID = [self makeCourseDialogKey:course];
            model.groupName = groupName;
            model.date = course.createdAt;
            
            model.groupAvatarPath = @"";
            
            [groups addObject:model];
            
            
        }
        
        if (completionBlock) {
            completionBlock(groups);
        }
        
    }];
    
}

+ (NSString *)makeCourseDialogKey:(PFObject *)course
{
    PFObject * term = (PFObject*)course[@"term"];
    NSString * name = [NSString stringWithFormat:@"%@ %@", course[@"summary"], term[@"name"]];
    NSString * key = [name stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    key = [key stringByReplacingOccurrencesOfString:@" " withString:@"-"];
 
    return key;
}

- (void)recreateLocalDialogsForGroupsWithCompletionBlock:(void(^)(void))completionBlcok {
    
    dispatch_group_t serviceGroup = dispatch_group_create();
    
 
    

   
    
    for (TLGroup * group in [TLFriendHelper sharedFriendHelper].groupsData) {
        
        dispatch_group_enter(serviceGroup);
        
        [self createCourseDialogWithLatestMessage:group completionBlock:^{
            TLConversation * conversation = [[TLMessageManager sharedInstance].conversationStore conversationByKey:group.groupID];
            
            if (conversation) {
                
            
                [[TLMessageManager sharedInstance].conversationStore countUnreadMessages:conversation withCompletionBlock:^(NSInteger count) {
                    
                    dispatch_group_leave(serviceGroup);
                    
                    
                }];
            }else{
                dispatch_group_leave(serviceGroup);
            }
            
            
            
            
            
            
        }];
        
    }
    
    dispatch_group_notify(serviceGroup, dispatch_get_main_queue(), ^{
        
        if (completionBlcok) {
            completionBlcok();
        }
        
    });
}

- (void)createCourseDialogWithLatestMessage:(TLGroup *)group completionBlock:(void(^)())completionBlock
{
    NSString * key = group.groupID;
    
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
        

        
                NSString * lastMsg = [[TLFriendHelper sharedFriendHelper] formatLastMessage:[TLMessage conversationContentForMessage:  object[@"lastMessage"]] fid:object[@"lastMessageSender"]];
                
                
                [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                      fid:key
                                                                                     type:TLConversationTypeGroup
                                                                                     date:object.createdAt
                                                                             last_message:lastMsg
                                                                     last_message_context:object[@"context"] ?: @""
                                                                                localOnly:YES];

        
            if (completionBlock) {
                completionBlock();
            }
            
//        }];
        
    }];
    
    
}



- (UIImage *)generateGroupName:(NSString*)groupID groupName:(NSString *)groupName {
    return [UIImage imageNamed:DEFAULT_AVATAR_PATH];
//    DefaultPortraitView *defaultPortrait = [[DefaultPortraitView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
//    [defaultPortrait setColorAndLabel:groupID Nickname:groupName];
//    UIImage *portrait = [defaultPortrait imageFromView];
//    return portrait;
}
    

@end
