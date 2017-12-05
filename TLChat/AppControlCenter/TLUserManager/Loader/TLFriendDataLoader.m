//
//  TLFriendDataLoader.m
//  TLChat
//
//  Created by Frank Mao on 2017-12-05.
//  Copyright © 2017 李伯坤. All rights reserved.
//

#import "TLFriendDataLoader.h"
#import <Parse/Parse.h>

@implementation TLFriendDataLoader

+ (void)p_loadFriendsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *friends))completionBlock {
    
    PFRelation * friendsRelation = [[PFUser currentUser] relationForKey:@"friends"];
    PFQuery * query = [friendsRelation query] ;
    query.cachePolicy = kPFCachePolicyCacheThenNetwork;
    
    NSMutableArray<TLUser*> *friends = [NSMutableArray array];
    
    [[friendsRelation query] findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        [friends removeAllObjects];
        
        NSLog(@"fetched %ld friends from server", objects.count);
        
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


@end
