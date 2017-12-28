//
//  TLFriendHelper.m
//  TLChat
//
//  Created by 李伯坤 on 16/1/27.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLFriendHelper.h"
#import "TLDBFriendStore.h"
#import "TLDBGroupStore.h"
#import "TLGroup+CreateAvatar.h"
#import "TLUserHelper.h"
#import "TLMessage.h"

//#import "TLAppDelegate.h"
#import "TLFriendDataLoader.h"
#import "TLGroupDataLoader.h"
#import "TLMessageManager+ConversationRecord.h"
#import "TLMacros.h"
#import <MJExtension/MJExtension.h>

@import Parse;

static TLFriendHelper *friendHelper = nil;

@interface TLFriendHelper ()

@property (nonatomic, strong) TLDBFriendStore *friendStore;

@property (nonatomic, strong) TLDBGroupStore *groupStore;

@property (nonatomic, strong) NSArray<PFObject*> * users;

@end

@implementation TLFriendHelper {
    BOOL _isLoading;
}

+ (TLFriendHelper *)sharedFriendHelper
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        friendHelper = [[TLFriendHelper alloc] init];
        
        PFQuery * query = [PFUser query];
        [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
            friendHelper.users = objects;
        }];
    });
    return friendHelper;
}

- (void)reset {
    self.friendsData = [@[] mutableCopy];
    self.groupsData = [@[] mutableCopy];
    _friendStore = nil;
    _groupsData = nil;
    [self p_resetFriendData];
   
}

- (id)init
{
    if (self = [super init]) {
        // 初始化好友数据
        self.friendsData = [self.friendStore friendsDataByUid:[TLUserHelper sharedHelper].userID];
        self.data = [[NSMutableArray alloc] initWithObjects:self.defaultGroup, nil];
        self.sectionHeaders = [[NSMutableArray alloc] initWithObjects:UITableViewIndexSearch, nil];
        // 初始化群数据
        self.groupsData = [self.groupStore groupsDataByUid:[TLUserHelper sharedHelper].userID];
        // 初始化标签数据
        self.tagsData = [[NSMutableArray alloc] init];
//        [self p_initTestData];
//        [self p_initTestGroupData];
        
        if ([[TLUserHelper sharedHelper] isLogin]) {
            
            [self loadFriendsAndGroupsData];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadFriendsAndGroupsData) name:kAKUserLoggedInNotification object:nil];
 
    }
    return self;
}

- (void)loadFriendsAndGroupsData {
    
    if (_isLoading) {
        return;
    }
    
    _isLoading = YES;
    
    dispatch_group_t serviceGroup = dispatch_group_create();
    
    dispatch_group_enter(serviceGroup);
    NSLog(@"p_loadFriendsDataWithCompleetionBlcok started");
    [self p_loadFriendsDataWithCompleetionBlcok:^{
        dispatch_group_leave(serviceGroup);
        NSLog(@"p_loadFriendsDataWithCompleetionBlcok finished");
    }];
    
    dispatch_group_enter(serviceGroup);
    NSLog(@"p_loadGroupsDataWithCompleetionBlcok started");
    [self p_loadGroupsDataWithCompleetionBlcok:^{
        dispatch_group_leave(serviceGroup);
        NSLog(@"p_loadGroupsDataWithCompleetionBlcok finished");
    }];
    
    dispatch_group_notify(serviceGroup, dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kAKFriendsAndGroupDataUpdateNotification object:nil];
        NSLog(@"sending kAKFriendsAndGroupDataUpdateNotification");
        
        _isLoading = NO;
    });
}

#pragma mark - Public Methods -
- (NSString *)makeDialogNameForFriend:(NSString *)fid myId:(NSString *)uid{
    NSArray * ids = [@[uid, fid]  sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    return [ids componentsJoinedByString:@":"];
}

- (NSString *)formatLastMessage:(TLMessage *)message {
    return [self formatLastMessage:[message conversationContent] fid:message.userID];
}

- (NSString *)formatLastMessage:(NSString *)content fid:(NSString *)fid {
    NSString * lastMsg = @"";
    
    NSString * message = content;
    if ([fid isEqualToString:[TLUserHelper sharedHelper].userID]) {
        lastMsg = message;
    }else{
        TLUser * user = [self getFriendInfoByUserID:fid];
        
        lastMsg = [NSString stringWithFormat:@"%@: %@", user.nikeName, message];
    }
    return lastMsg;
}

- (TLUser *)getFriendInfoByUserID:(NSString *)userID
{
    if (userID == nil) {
        return nil;
    }
    for (TLUser *user in self.friendsData) {
        if ([user.userID isEqualToString:userID]) {
            return user;
        }
    }
    
    // TODO: persisent to db.
    NSArray * matches = [self.users filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"objectId == %@", userID]];
    if (matches.count > 0) {
        PFUser * userObject = matches.firstObject;
        
        TLUser * user = [TLUser new];
        user.userID = userObject.objectId;
//        DLog(@"user name: %@", userObject.username);
        user.username = userObject.username;
        user.nikeName = userObject[kParseUserClassAttributeNickname] ?: user.username ;
        
        PFFile * file = userObject[kParseUserClassAttributeAvatar];
        if (file) {
            user.avatarURL = file.url;
        }
        
        
        return user;
    }
    
    PFQuery * query = [PFUser query];
    query.cachePolicy = kPFCachePolicyNetworkOnly;
    [query whereKey:@"objectId" equalTo:userID];
    PFUser * userObject = [query getFirstObject];
    
    TLUser * user = [TLUser new];
    user.userID = userObject.objectId;
    DLog(@"user name: %@", userObject[kParseUserClassAttributeNickname]);
    user.username = userObject.username;
    user.nikeName = userObject[kParseUserClassAttributeNickname] ?: user.username;
    
    PFFile * file = userObject[kParseUserClassAttributeAvatar];
    if (file) {
        user.avatarURL = file.url;
    }
    
    
    return user;
}

- (TLGroup *)getGroupInfoByGroupID:(NSString *)groupID
{
    if (groupID == nil) {
        return nil;
    }
    for (TLGroup *group in self.groupsData) {
        if ([group.groupID isEqualToString:groupID]) {
            return group;
        }
    }
    return nil;
}

#pragma mark - Private Methods -
- (void)p_resetFriendData
{
    // 1、排序
    NSArray *serializeArray = [self.friendsData sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        int i;
        NSString *strA = ((TLUser *)obj1).pinyin;
        NSString *strB = ((TLUser *)obj2).pinyin;
        for (i = 0; i < strA.length && i < strB.length; i ++) {
            char a = toupper([strA characterAtIndex:i]);
            char b = toupper([strB characterAtIndex:i]);
            if (a > b) {
                return (NSComparisonResult)NSOrderedDescending;
            }
            else if (a < b) {
                return (NSComparisonResult)NSOrderedAscending;
            }
        }
        if (strA.length > strB.length) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        else if (strA.length < strB.length){
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    // 2、分组
    NSMutableArray *ansData = [[NSMutableArray alloc] initWithObjects:self.defaultGroup, nil];
    NSMutableArray *ansSectionHeaders = [[NSMutableArray alloc] initWithObjects:UITableViewIndexSearch, nil];
    NSMutableDictionary *tagsDic = [[NSMutableDictionary alloc] init];
    char lastC = '1';
    TLUserGroup *curGroup;
    TLUserGroup *othGroup = [[TLUserGroup alloc] init];
    [othGroup setGroupName:@"#"];
    for (TLUser *user in serializeArray) {
        // 获取拼音失败
        if (user.pinyin == nil || user.pinyin.length == 0) {
            [othGroup addObject:user];
            continue;
        }
        
        char c = toupper([user.pinyin characterAtIndex:0]);
        if (!isalpha(c)) {      // #组
            [othGroup addObject:user];
        }
        else if (c != lastC){
            if (curGroup && curGroup.count > 0) {
                [ansData addObject:curGroup];
                [ansSectionHeaders addObject:curGroup.groupName];
            }
            lastC = c;
            curGroup = [[TLUserGroup alloc] init];
            [curGroup setGroupName:[NSString stringWithFormat:@"%c", c]];
            [curGroup addObject:user];
        }
        else {
            [curGroup addObject:user];
        }
        
        // TAGs
        if (user.detailInfo.tags.count > 0) {
            for (NSString *tag in user.detailInfo.tags) {
                TLUserGroup *group = [tagsDic objectForKey:tag];
                if (group == nil) {
                    group = [[TLUserGroup alloc] init];
                    group.groupName = tag;
                    [tagsDic setObject:group forKey:tag];
                    [self.tagsData addObject:group];
                }
                [group.users addObject:user];
            }
        }
    }
    if (curGroup && curGroup.count > 0) {
        [ansData addObject:curGroup];
        [ansSectionHeaders addObject:curGroup.groupName];
    }
    if (othGroup.count > 0) {
        [ansData addObject:othGroup];
        [ansSectionHeaders addObject:othGroup.groupName];
    }
    
    [self.data removeAllObjects];
    [self.data addObjectsFromArray:ansData];
    [self.sectionHeaders removeAllObjects];
    [self.sectionHeaders addObjectsFromArray:ansSectionHeaders];
    if (self.dataChangedBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.dataChangedBlock(self.data, self.sectionHeaders, self.friendCount);
        });
    }
}

- (void)p_loadFriendsDataWithCompleetionBlcok:(void(^)())completionBlock
{
    [[TLFriendDataLoader sharedFriendDataLoader] p_loadFriendsDataWithCompletionBlock:^(NSArray<TLUser *> *friends) {
        
 
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self p_resetFriendData];
        });
        
        // 更新好友数据到数据库
        
        self.friendsData = [friends mutableCopy];
        BOOL ok = [self.friendStore updateFriendsData:self.friendsData forUid:[TLUserHelper sharedHelper].userID];
        if (!ok) {
            DDLogError(@"保存好友数据到数据库失败!");
        }
 
        


        [[TLFriendDataLoader sharedFriendDataLoader] recreateLocalDialogsForFriendsWithCompletionBlock:^{
            
            if (completionBlock) {
                completionBlock();
            }
        }];

   

    
    }];
    
}

- (void)p_loadGroupsDataWithCompleetionBlcok:(void(^)())completionBlock
{
    [TLGroupDataLoader p_loadGroupsDataWithCompletionBlock:^(NSArray<TLGroup *> *groups) {

        self.groupsData = [groups mutableCopy];
        
        
        
        BOOL ok = [self.groupStore updateGroupsData:self.groupsData forUid:[TLUserHelper sharedHelper].userID];
        if (!ok) {
            DDLogError(@"保存群数据到数据库失败!");
        }
        // 生成Group Icon
        for (TLGroup *group in self.groupsData) {
            [group createGroupAvatarWithCompleteAction:nil];
        }
        
 

        [[TLGroupDataLoader sharedGroupDataLoader] recreateLocalDialogsForGroupsWithCompletionBlock:^{
        
            if (completionBlock) {
                completionBlock();
            }
            
        }];
        
        
        
    }];
    
}

- (void)p_initTestFriendsData
{
    // 好友数据
    NSString *path = [[NSBundle mainBundle] pathForResource:@"FriendList" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
    NSArray *arr = [TLUser mj_objectArrayWithKeyValuesArray:jsonArray];
    [self.friendsData removeAllObjects];
    [self.friendsData addObjectsFromArray:arr];
    // 更新好友数据到数据库
    BOOL ok = [self.friendStore updateFriendsData:self.friendsData forUid:[TLUserHelper sharedHelper].userID];
    if (!ok) {
        DDLogError(@"保存好友数据到数据库失败!");
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self p_resetFriendData];
    });
    
}



- (void)p_initTestGroupData
{
    // 群数据
    NSString *path = [[NSBundle mainBundle] pathForResource:@"FriendGroupList" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
    NSArray *arr = [TLGroup mj_objectArrayWithKeyValuesArray:jsonArray];
    [self.groupsData removeAllObjects];
    [self.groupsData addObjectsFromArray:arr];
    BOOL ok = [self.groupStore updateGroupsData:self.groupsData forUid:[TLUserHelper sharedHelper].userID];
    if (!ok) {
        DDLogError(@"保存群数据到数据库失败!");
    }
    // 生成Group Icon
    for (TLGroup *group in self.groupsData) {
        [group createGroupAvatarWithCompleteAction:nil];
    }
}

#pragma mark - Getter
- (TLUserGroup *)defaultGroup
{
    if (_defaultGroup == nil) {
        TLUser *item_new = [[TLUser alloc] init];
        item_new.userID = @"-1";
        item_new.avatarPath = @"friends_new";
        item_new.remarkName = @"新的朋友";
        TLUser *item_group = [[TLUser alloc] init];
        item_group.userID = @"-2";
        item_group.avatarPath = @"friends_group";
        item_group.remarkName = @"群聊";
        TLUser *item_tag = [[TLUser alloc] init];
        item_tag.userID = @"-3";
        item_tag.avatarPath = @"friends_tag";
        item_tag.remarkName = @"标签";
        TLUser *item_public = [[TLUser alloc] init];
        item_public.userID = @"-4";
        item_public.avatarPath = @"friends_public";
        item_public.remarkName = @"公共号";
        _defaultGroup = [[TLUserGroup alloc] initWithGroupName:nil users:[NSMutableArray arrayWithObjects:item_new, item_group, item_tag, item_public, nil]];
    }
    return _defaultGroup;
}

- (NSInteger)friendCount
{
    return self.friendsData.count;
}

- (TLDBFriendStore *)friendStore
{
    if (_friendStore == nil) {
        _friendStore = [[TLDBFriendStore alloc] init];
    }
    return _friendStore;
}

- (TLDBGroupStore *)groupStore
{
    if (_groupStore == nil) {
        _groupStore = [[TLDBGroupStore alloc] init];
    }
    return _groupStore;
}

- (void)deleteFriend:(NSString *)fid
{
    [self.friendStore deleteFriendByFid:fid forUid:[TLUserHelper sharedHelper].userID];
    
    [[TLMessageManager sharedInstance] deleteConversationByPartnerID:fid];
    
    NSString * key = [self makeDialogNameForFriend:fid myId:[TLUserHelper sharedHelper].userID];
    PFQuery * query = [PFQuery queryWithClassName:kParseClassNameDialog];
    [query whereKey:@"key" equalTo:key];
    [query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        if (objects) {
            [PFObject deleteAllInBackground:objects];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kAKFriendsAndGroupDataUpdateNotification object:nil];
   
    
}
@end
