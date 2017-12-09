//
//  TLDBConversationStore.m
//  TLChat
//
//  Created by 李伯坤 on 16/3/20.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLDBConversationStore.h"
#import "TLDBMessageStore.h"
#import "TLDBConversationSQL.h"
#import "TLDBManager.h"
#import "TLConversation.h"
#import "TLMacros.h"
#import "TLFriendHelper.h"
#import <Parse/Parse.h>
#import "TLUserHelper.h"

@interface TLDBConversationStore ()

@property (nonatomic, strong) TLDBMessageStore *messageStore;

@end

@implementation TLDBConversationStore {
    BOOL _isQueryingDialog;
}

- (id)init
{
    if (self = [super init]) {
        self.dbQueue = [TLDBManager sharedInstance].messageQueue;
        BOOL ok = [self createTable];
        if (!ok) {
            DDLogError(@"DB: 聊天记录表创建失败");
        }
    }
    return self;
}

- (BOOL)createTable
{
    NSString *sqlString = [NSString stringWithFormat:SQL_CREATE_CONV_TABLE, CONV_TABLE_NAME];
    return [self createTable:CONV_TABLE_NAME withSQL:sqlString];
}

- (BOOL)addConversationByUid:(NSString *)uid fid:(NSString *)fid type:(NSInteger)type date:(NSDate *)date last_message:(NSString*)last_message localOnly:(BOOL)localOnly;
{
    NSString * dialogKey = @"";
    NSString * dialogName = @"";
    if (type == 1) { //group
        dialogKey = fid;
        TLGroup * group = [[TLFriendHelper sharedFriendHelper] getGroupInfoByGroupID:fid];
        dialogName = group.groupName;
    }else{
        dialogKey = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:fid myId:uid];
        
        TLUser *user = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:fid];
        dialogName = user.nikeName;
    }
    NSDate * lastReadDate = date ?: [self lastReadDateByUid:uid fid:fid];
    
//    NSInteger unreadCount = [self unreadMessageByUid:uid fid:fid] + 1;
    NSString *sqlString = [NSString stringWithFormat:SQL_ADD_CONV, CONV_TABLE_NAME];
    NSArray *arrPara = [NSArray arrayWithObjects:
                        uid,
                        fid,
                        [NSNumber numberWithInteger:type],
                        TLTimeStamp(lastReadDate),
//                        [NSNumber numberWithInteger:unreadCount], // don't increase here, which is done by separated method.
                        last_message,
                        dialogKey,
                        
                        @"", @"", @"", @"", @"", nil];
    BOOL ok = [self excuteSQL:sqlString withArrParameter:arrPara];
    
    
    // Server data

    
    
    if (localOnly || _isQueryingDialog) {
        return ok;
    }
    
    PFQuery * query = [PFQuery queryWithClassName:kParseClassNameDialog];
    [query whereKey:@"key" equalTo:dialogKey];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    
    _isQueryingDialog = YES;
    [query countObjectsInBackgroundWithBlock:^(int number, NSError * _Nullable error) {
        _isQueryingDialog = NO;
        if (number == 0) {
            PFObject * dialog = [PFObject objectWithClassName:kParseClassNameDialog];
            
            dialog[@"type"] = @(type);
            dialog[@"key"] = dialogKey;
            dialog[@"user"] = [PFUser currentUser];
            

            dialog[@"name"] = dialogName;
            
            [dialog saveEventually];
        }
    }];
    

    
    return ok;
}


/**
 *  更新会话状态（已读）
 */
- (void)updateConversationByUid:(NSString *)uid fid:(NSString *)fid unreadCount:(NSInteger)unreadCount
{

    NSString *sqlString = [NSString stringWithFormat:SQL_UPDATE_CONV, CONV_TABLE_NAME, unreadCount, uid, fid];
    
    [self excuteSQL:sqlString withArrParameter:nil];
    
    return;
}

- (void)resetUnreadNumberForConversationByUid:(NSString *)uid fid:(NSString *)fid
{
    [self updateConversationByUid:uid fid:fid unreadCount:0];
    
    return;
}

- (void)increaseUnreadNumberForConversationByUid:(NSString *)uid fid:(NSString *)fid addNumber:(NSInteger)addNumber
{
    NSInteger unreadCount = [self unreadMessageByUid:uid fid:fid] + addNumber;
    [self updateConversationByUid:uid fid:fid unreadCount:unreadCount];
    
    return;
}

- (void)increaseUnreadNumberForConversationByUid:(NSString *)uid fid:(NSString *)fid
{
    [self increaseUnreadNumberForConversationByUid:uid fid:fid addNumber:1];
    return;
}
/**
 *  查询所有会话
 */
- (NSArray *)conversationsByUid:(NSString *)uid
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat: SQL_SELECT_CONVS, CONV_TABLE_NAME, uid];
    
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLConversation *conversation = [[TLConversation alloc] init];
            conversation.partnerID = [retSet stringForColumn:@"fid"];
            conversation.convType = [retSet intForColumn:@"conv_type"];
            NSString *dateString = [retSet stringForColumn:@"date"];
            conversation.date = [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue];
            conversation.unreadCount = [retSet intForColumn:@"unread_count"];
            conversation.content = [retSet stringForColumn:@"last_message"];
            conversation.key = [retSet stringForColumn:@"key"];
            [data addObject:conversation];
        }
        [retSet close];
    }];
    
    // 获取conv对应的msg // TODO: move to conversation header
//    for (TLConversation *conversation in data) {
//        TLMessage * message = [self.messageStore lastMessageByUserID:uid partnerID:conversation.partnerID];
//        if (message) {
//            conversation.content = [message conversationContent];
//            conversation.date = message.date;
//        }
//    }
    
    return data;
}

- (TLConversation *)conversationByKey:(NSString *)key
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat: SQL_SELECT_CONV_BY_KEY, CONV_TABLE_NAME, key];
    
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLConversation *conversation = [[TLConversation alloc] init];
            conversation.partnerID = [retSet stringForColumn:@"fid"];
            conversation.convType = [retSet intForColumn:@"conv_type"];
            NSString *dateString = [retSet stringForColumn:@"date"];
            conversation.date = [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue];
            conversation.unreadCount = [retSet intForColumn:@"unread_count"];
            conversation.content = [retSet stringForColumn:@"last_message"];
            conversation.key = [retSet stringForColumn:@"key"];
            [data addObject:conversation];
        }
        [retSet close];
    }];
    
    // 获取conv对应的msg // TODO: move to conversation header
    //    for (TLConversation *conversation in data) {
    //        TLMessage * message = [self.messageStore lastMessageByUserID:uid partnerID:conversation.partnerID];
    //        if (message) {
    //            conversation.content = [message conversationContent];
    //            conversation.date = message.date;
    //        }
    //    }
    
    
    return data.firstObject;
}

- (NSInteger)unreadMessageByUid:(NSString *)uid fid:(NSString *)fid
{
    __block NSInteger unreadCount = 0;
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_CONV_UNREAD, CONV_TABLE_NAME, uid, fid];
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        if ([retSet next]) {
            unreadCount = [retSet intForColumn:@"unread_count"];
        }
        [retSet close];
    }];
    return unreadCount;
}

- (NSDate*)lastReadDateByUid:(NSString *)uid fid:(NSString *)fid
{
    __block NSDate * lastReadDate = nil;
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_CONV_DATE, CONV_TABLE_NAME, uid, fid];
    
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        if ([retSet next]) {
            NSString *dateString = [retSet stringForColumn:@"date"];
            lastReadDate = [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue];
        }
        [retSet close];
    }];
    
    return lastReadDate;
}

/**
 *  删除单条会话
 */
- (BOOL)deleteConversationByUid:(NSString *)uid fid:(NSString *)fid
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_CONV, CONV_TABLE_NAME, uid, fid];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

/**
 *  删除用户的所有会话
 */
- (BOOL)deleteConversationsByUid:(NSString *)uid
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_ALL_CONVS, CONV_TABLE_NAME, uid];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

#pragma mark - Getter -
- (TLDBMessageStore *)messageStore
{
    if (_messageStore == nil) {
        _messageStore = [[TLDBMessageStore alloc] init];
    }
    return _messageStore;
}

- (void)countUnreadMessages:(TLConversation *)conversation
{
    NSString * key = conversation.key;
    PFQuery * query = [PFQuery queryWithClassName:kParseClassNameMessage];
    [query whereKey:@"dialogKey" equalTo:key];
    [query whereKey:@"createdAt" greaterThan:conversation.date];
    [query orderByDescending:@"createdAt"];
    
    [query countObjectsInBackgroundWithBlock:^(int number, NSError * _Nullable error) {
        if (number > 0) {
            
            [self increaseUnreadNumberForConversationByUid:[TLUserHelper sharedHelper].userID fid:key addNumber:number];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kAKGroupLastMessageUpdateNotification object:nil];
        }
        
        
    }];
}

@end
