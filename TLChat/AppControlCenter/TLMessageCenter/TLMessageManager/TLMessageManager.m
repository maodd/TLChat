//
//  TLMessageManager.m
//  TLChat
//
//  Created by 李伯坤 on 16/3/13.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLMessageManager.h"
#import "TLMessageManager+ConversationRecord.h"
#import "TLUserHelper.h"
#import "TLMacros.h"
#import "TLTextMessage.h"

static TLMessageManager *messageManager;

@implementation TLMessageManager

+ (TLMessageManager *)sharedInstance
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        messageManager = [[TLMessageManager alloc] init];
    });
    return messageManager;
}

- (void)sendMessage:(TLMessage *)message
           progress:(void (^)(TLMessage *, CGFloat))progress
            success:(void (^)(TLMessage *))success
            failure:(void (^)(TLMessage *))failure
{
    BOOL ok = [self.messageStore addMessage:message];
    if (!ok) {
        DDLogError(@"存储Message到DB失败");
        
        failure(message);
        return;
    }
    else {      // 存储到conversation
        ok = [self addConversationByMessage:message];
        if (!ok) {
            DDLogError(@"存储Conversation到DB失败");
            failure(message);
            return;
        }
    }
    
    success(message);
    // move server saving code here.
}


#pragma mark - Getter -
- (TLDBMessageStore *)messageStore
{
    if (_messageStore == nil) {
        _messageStore = [[TLDBMessageStore alloc] init];
    }
    return _messageStore;
}

- (TLDBConversationStore *)conversationStore
{
    if (_conversationStore == nil) {
        _conversationStore = [[TLDBConversationStore alloc] init];
    }
    return _conversationStore;
}

- (NSString *)userID
{
    return [TLUserHelper sharedHelper].userID;
}


# pragma mark - send message to the other user in background

- (void)sendTextMessageToUser:(NSString *)userId messageContent:(NSString *)messageContent context:(NSString *)context
{
    TLTextMessage * message = [[TLTextMessage alloc] init];
    message.ownerTyper = TLMessageOwnerTypeSelf;
    message.userID = [TLUserHelper sharedHelper].userID;
    message.fromUser = (id<TLChatUserProtocol>)[TLUserHelper sharedHelper].user;
    message.date = [NSDate date];
    message.text = messageContent;
    message.context = context;
    
    
    message.partnerType = TLPartnerTypeUser;
    message.friendID = userId;
    
    
    
    [[TLMessageManager sharedInstance] sendMessage:message progress:^(TLMessage * message, CGFloat pregress) {
        
    } success:^(TLMessage * message) {
        NSLog(@"send success");
        
        
        
        
    } failure:^(TLMessage * message) {
        NSLog(@"send failure");
    }];
    
//    [[TLMessageManager sharedInstance].conversationStore updateLastReadDateForConversationByUid:[self.partner chat_userID] key:self.conversationKey];
}
@end
