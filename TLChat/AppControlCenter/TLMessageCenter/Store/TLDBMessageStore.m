//
//  TLDBMessageStore.m
//  TLChat
//
//  Created by 李伯坤 on 16/3/13.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLDBMessageStore.h"
#import "TLDBMessageStoreSQL.h"
#import "TLMacros.h"
#import <Parse/Parse.h>
#import "TLImageMessage.h"
#import "TLVoiceMessage.h"
#import "TLFriendHelper.h"

@implementation TLDBMessageStore

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
    NSString *sqlString = [NSString stringWithFormat:SQL_CREATE_MESSAGE_TABLE, MESSAGE_TABLE_NAME];
    return [self createTable:MESSAGE_TABLE_NAME withSQL:sqlString];
}

- (BOOL)addMessage:(TLMessage *)message
{
    if (message == nil || message.userID == nil || message.messageID == nil || (message.friendID == nil && message.groupID == nil)) {
        return NO;
    }
    
    NSString *fid = @"";
    NSString *subfid;
    if (message.partnerType == TLPartnerTypeUser) {
        fid = message.friendID;
    }
    else {
        fid = message.groupID;
        subfid = message.friendID;
    }
    
    NSString *sqlString = [NSString stringWithFormat:SQL_ADD_MESSAGE, MESSAGE_TABLE_NAME];
    BOOL ok = YES;

    
    NSArray *arrPara = [NSArray arrayWithObjects:
                        message.messageID,
                        message.userID,
                        fid,
                        TLNoNilString(subfid),
                        TLTimeStamp(message.date),
                        [NSNumber numberWithInteger:message.partnerType],
                        [NSNumber numberWithInteger:message.ownerTyper],
                        [NSNumber numberWithInteger:message.messageType],
                        [message.content mj_JSONString],
                        [NSNumber numberWithInteger:message.sendState],
                        [NSNumber numberWithInteger:message.readState],
                        @"", @"", @"", @"", @"", nil];
     ok = [self excuteSQL:sqlString withArrParameter:arrPara];
    
   if (!message.SavedOnServer) {
           /// server side save
        
        PFObject * msgObject = [PFObject objectWithClassName:kParseClassNameMessage];
        msgObject[@"message"] = [message.content mj_JSONString];
    //    msgObject[@"readAt"] = @(message.readState);
        msgObject[@"sender"] = [PFUser currentUser].objectId; // quick way to set pointer
       msgObject[@"localID"] = message.messageID;
       
        if ([message isKindOfClass:[TLImageMessage class]]) {
            TLImageMessage * imageMessage = (TLImageMessage*)message;
            if (imageMessage.imageData) {
                
                if ([imageMessage.imageData length] > 10 * 1024 * 1024) {
                    CGSize newSize = CGSizeMake(1000, 1000 * imageMessage.imageSize.height / imageMessage.imageSize.width);
                    UIImage * newImage = [[UIImage imageWithData:imageMessage.imageData] scalingToSize:newSize];
                    imageMessage.imageData = UIImageJPEGRepresentation(newImage, 1.0);
                }
                
                PFFile * file = [PFFile fileWithData:imageMessage.imageData];
                msgObject[@"attachment"] = file;
                
                
                CGSize thumbnailSize = CGSizeMake(100, 100 * imageMessage.imageSize.height / imageMessage.imageSize.width);
                UIImage * thumbnailImage = [[UIImage imageWithData:imageMessage.imageData] scalingToSize:thumbnailSize];
                PFFile * thumbnail = [PFFile fileWithData:UIImageJPEGRepresentation(thumbnailImage, 0.5)];
                msgObject[@"thumbnail"] = thumbnail;
                
                
                
            }
        }else if ([message isKindOfClass:[TLVoiceMessage class]]) {
            TLVoiceMessage * voiceMessage = (TLVoiceMessage*)message;
            if ([voiceMessage path]) {
                NSData * data = [NSData dataWithContentsOfFile:voiceMessage.path];
                if (data) {
                    PFFile * file = [PFFile fileWithData:data];
                    msgObject[@"attachment"] = file;
                }
                
            }
            
            
        }
        

        NSString * dialogKey = @"";
        if (message.partnerType == TLPartnerTypeUser) {
            dialogKey = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:  message.friendID myId:message.userID];
        }else {
            dialogKey = message.groupID;
        }
        
        msgObject[@"dialogKey"] = dialogKey;
        [msgObject saveInBackground];

        
    }
    
    
    
    
    
    return ok;
}



- (void)messagesByUserID:(NSString *)userID partnerID:(NSString *)partnerID fromDate:(NSDate *)date count:(NSUInteger)count complete:(void (^)(NSArray *, BOOL))complete
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat:
                        SQL_SELECT_MESSAGES_PAGE,
                        MESSAGE_TABLE_NAME,
//                        userID,
                        partnerID,
                        [NSString stringWithFormat:@"%lf", date.timeIntervalSince1970],
                        (long)(count + 1)];

    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLMessage *message = [self p_createDBMessageByFMResultSet:retSet];
            [data insertObject:message atIndex:0];
        }
        [retSet close];
    }];
    
    BOOL hasMore = NO;
    if (data.count == count + 1) {
        hasMore = YES;
        [data removeObjectAtIndex:0];
    }
    complete(data, hasMore);
}

- (NSArray *)chatFilesByUserID:(NSString *)userID partnerID:(NSString *)partnerID
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_CHAT_FILES, MESSAGE_TABLE_NAME, userID, partnerID];
    
    __block NSDate *lastDate = [NSDate date];
    __block NSMutableArray *array = [[NSMutableArray alloc] init];
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLMessage * message = [self p_createDBMessageByFMResultSet:retSet];
            if (([message.date isThisWeek] && [lastDate isThisWeek]) || (![message.date isThisWeek] && [lastDate isSameMonthAsDate:message.date])) {
                [array addObject:message];
            }
            else {
                lastDate = message.date;
                if (array.count > 0) {
                    [data addObject:array];
                }
                array = [[NSMutableArray alloc] initWithObjects:message, nil];
            }
        }
        if (array.count > 0) {
            [data addObject:array];
        }
        [retSet close];
    }];
    return data;
}

- (NSArray *)chatImagesAndVideosByUserID:(NSString *)userID partnerID:(NSString *)partnerID
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_CHAT_MEDIA, MESSAGE_TABLE_NAME, partnerID];
    
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLMessage *message = [self p_createDBMessageByFMResultSet:retSet];
            [data addObject:message];
        }
        [retSet close];
    }];
    return data;
}

- (TLMessage *)lastMessageByUserID:(NSString *)userID partnerID:(NSString *)partnerID
{
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_LAST_MESSAGE, MESSAGE_TABLE_NAME, MESSAGE_TABLE_NAME, userID, partnerID];
    __block TLMessage * message;
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            message = [self p_createDBMessageByFMResultSet:retSet];
        }
        [retSet close];
    }];
    return message;
}

- (BOOL)deleteMessageByMessageID:(NSString *)messageID
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_MESSAGE, MESSAGE_TABLE_NAME, messageID];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

- (BOOL)deleteMessagesByUserID:(NSString *)userID partnerID:(NSString *)partnerID;
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_FRIEND_MESSAGES, MESSAGE_TABLE_NAME, userID, partnerID];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

- (BOOL)deleteMessagesByUserID:(NSString *)userID
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_USER_MESSAGES, MESSAGE_TABLE_NAME, userID];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

#pragma mark - Private Methods -
- (TLMessage *)p_createDBMessageByFMResultSet:(FMResultSet *)retSet
{
    TLMessageType type = [retSet intForColumn:@"msg_type"];
    TLMessage * message = [TLMessage createMessageByType:type];
    message.messageID = [retSet stringForColumn:@"msgid"];
    message.userID = [retSet stringForColumn:@"uid"];
    message.partnerType = [retSet intForColumn:@"partner_type"];
    if (message.partnerType == TLPartnerTypeGroup) {
        message.groupID = [retSet stringForColumn:@"fid"];
        message.friendID = [retSet stringForColumn:@"subfid"];
    }
    else {
        message.friendID = [retSet stringForColumn:@"fid"];
        message.groupID = [retSet stringForColumn:@"subfid"];
    }
    NSString *dateString = [retSet stringForColumn:@"date"];
    message.date = [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue];
    message.ownerTyper = [retSet intForColumn:@"own_type"];
    NSString *content = [retSet stringForColumn:@"content"];
    message.content = [[NSMutableDictionary alloc] initWithDictionary:[content mj_JSONObject]];
    message.sendState = [retSet intForColumn:@"send_status"];
    message.readState = [retSet intForColumn:@"received_status"];
    return message;
}

@end
