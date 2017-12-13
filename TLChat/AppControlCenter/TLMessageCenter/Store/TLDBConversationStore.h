//
//  TLDBConversationStore.h
//  TLChat
//
//  Created by 李伯坤 on 16/3/20.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLDBBaseStore.h"
#import "TLConversation.h"

@interface TLDBConversationStore : TLDBBaseStore

/**
 *  新的会话（未读）
 */
- (BOOL)addConversationByUid:(NSString *)uid fid:(NSString *)fid type:(NSInteger)type date:(NSDate *)date last_message:(NSString*)last_message localOnly:(BOOL)localOnly;

/**
 *  更新会话状态（已读）
 */
- (void)resetUnreadNumberForConversationByUid:(NSString *)uid key:(NSString *)key;
- (void)increaseUnreadNumberForConversationByUid:(NSString *)uid key:(NSString *)key;
- (void)increaseUnreadNumberForConversationByUid:(NSString *)uid key:(NSString *)key addNumber:(NSInteger)addNumber;
- (void)updateLastReadDateForConversationByUid:(NSString *)uid key:(NSString *)key;

/**
 *  查询所有会话
 */
- (NSArray *)conversationsByUid:(NSString *)uid;

- (TLConversation *)conversationByKey:(NSString *)key;

/**
 *  未读消息数
 */
- (NSInteger)unreadMessageByUid:(NSString *)uid key:(NSString *)key;

/**
 *  删除单条会话
 */
- (BOOL)deleteConversationByUid:(NSString *)uid fid:(NSString *)fid;

/**
 *  删除用户的所有会话
 */
- (BOOL)deleteConversationsByUid:(NSString *)uid;

- (void)countUnreadMessages:(TLConversation *)conversation withCompletionBlock:(void(^)())completionBlock;


@end
