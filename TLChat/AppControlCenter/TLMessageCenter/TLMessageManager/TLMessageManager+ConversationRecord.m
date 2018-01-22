//
//  TLMessageManager+ConversationRecord.m
//  TLChat
//
//  Created by 李伯坤 on 16/3/20.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLMessageManager+ConversationRecord.h"
#import "TLMessageManager+MessageRecord.h"
#import "TLUserHelper.h"
#import "TLGroup.h"
#import "TLFriendHelper.h"
#import "TLConversation.h"

@implementation TLMessageManager (ConversationRecord)

- (BOOL)addConversationByMessage:(TLMessage *)message
{
    NSString *partnerID = message.friendID;
    NSInteger type = 0;
    if (message.partnerType == TLPartnerTypeGroup) {
        partnerID = message.groupID;
        type = 1;
    }
    
    NSString * lastMsg = [[TLFriendHelper sharedFriendHelper] formatLastMessage:message];
    
    BOOL ok = [self.conversationStore addConversationByUid:[TLUserHelper sharedHelper].userID fid:partnerID type:type date:message.date last_message:lastMsg
               last_message_context:message.context
                                                 localOnly:NO];
    
    return ok;
}

- (void)conversationRecord:(void (^)(NSArray *))complete
{
    NSArray *data = [self.conversationStore conversationsByUid:self.userID];
    complete(data);
}

- (BOOL)deleteConversationByPartnerID:(NSString *)partnerID
{
    BOOL ok = [self deleteMessagesByPartnerID:partnerID];
    if (ok) {
        ok = [self.conversationStore deleteConversationByUid:self.userID fid:partnerID];
    }

    return ok;
}

- (void)refreshConversationRecord
{
    NSArray<NSString*> * groupIds = [[TLFriendHelper sharedFriendHelper].groupsData valueForKeyPath:@"groupID"];
    NSArray<TLConversation*> * oldData = [self.conversationStore conversationsByUid:self.userID];
    for (TLConversation * conv in oldData) {
        if (conv.convType == TLConversationTypeGroup && ![groupIds containsObject: conv.partnerID]) {
            [self deleteConversationByPartnerID:conv.partnerID];
        }
    }
   
    
}

@end
