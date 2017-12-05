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

@implementation TLGroupDataLoader

+ (void)p_loadGroupsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *groups))completionBlock {
    
    PFQuery * query = [PFQuery queryWithClassName:@"Course"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query includeKey:@"term"];
 
    NSMutableArray * groups = [NSMutableArray array];
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        [groups removeAllObjects];
        
        NSLog(@"fetched %ld groups from server", objects.count);
        
        for (PFObject * course in objects) {
            TLGroup * model = [TLGroup new];
            model.groupID = course.objectId;
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
@end
