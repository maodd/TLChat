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
#import "TLAppDelegate.h"
#import "TLFriendHelper.h"
#import "TLUser.h"

@implementation TLGroupDataLoader

+ (void)p_loadGroupsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *groups))completionBlock {
    
    PFQuery * query = [PFQuery queryWithClassName:@"Course"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query includeKey:@"term"];
 
    NSMutableArray * groups = [NSMutableArray array];
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        [groups removeAllObjects];
        
        NSLog(@"fetched %u groups from server", objects.count);
        
        for (PFObject * course in objects) {
            TLGroup * model = [TLGroup new];
            model.groupID = [self makeCourseDialogKey:course];
            PFObject * term = (PFObject*)course[@"term"];
            NSString * name = [NSString stringWithFormat:@"%@ (%@)", course[@"summary"], term[@"name"]];
            model.groupName = [name stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
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

+ (void)recreateLocalDialogsForGroups {
    for (TLGroup * group in [TLFriendHelper sharedFriendHelper].groupsData) {
        [self createCourseDialogWithLatestMessage:group];
    }
}

+ (void)createCourseDialogWithLatestMessage:(TLGroup *)group
{
    NSString * key = group.groupID;
    PFQuery * query = [PFQuery queryWithClassName:kParseClassNameMessage];
    [query whereKey:@"dialogKey" equalTo:key];
    [query orderByDescending:@"createdAt"];
    
    [query getFirstObjectInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        
        if (object) {
            NSString * content = [TLMessage conversationContentForMessage: object[@"message"]];
            NSString * lastMsg = [[TLFriendHelper sharedFriendHelper] formatLastMessage:content fid:object[@"sender"]];
             
            
            [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                  fid:key
                                                                                 type:TLConversationTypeGroup
                                                                                 date:object.createdAt
                                                                         last_message:lastMsg
                                                                            localOnly:YES]; 
        }else{
            [[TLMessageManager sharedInstance].conversationStore addConversationByUid:[PFUser currentUser].objectId
                                                                                  fid:key
                                                                                 type:TLConversationTypeGroup
                                                                                 date:[NSDate date]
                                                                         last_message:@"Welcome"
                                                                            localOnly:YES];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:kAKGroupDataUpdateNotification object:nil];
    }];
}
@end
