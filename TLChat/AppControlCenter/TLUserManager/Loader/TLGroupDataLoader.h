//
//  TLGroupDataLoader.h
//  TLChat
//
//  Created by Frank Mao on 2017-12-05.
//  Copyright © 2017 李伯坤. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TLGroup.h"

@interface TLGroupDataLoader : NSObject

+ (void)p_loadGroupsDataWithCompletionBlock:(void(^)(NSArray<TLUser*> *groups))completionBlock;

+ (void)recreateLocalDialogsForGroups;

+ (UIImage *)generateGroupName:(NSString*)groupID groupName:(NSString *)groupName;
+ (void)createCourseDialogWithLatestMessage:(TLGroup *)group completionBlock:(void(^)())completionBlock;

@end
