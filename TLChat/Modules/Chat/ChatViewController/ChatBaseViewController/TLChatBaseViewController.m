//
//  TLChatBaseViewController.m
//  TLChat
//
//  Created by 李伯坤 on 16/2/15.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLChatBaseViewController.h"
#import "TLChatBaseViewController+Proxy.h"
#import "TLChatBaseViewController+ChatBar.h"
#import "TLChatBaseViewController+MessageDisplayView.h"
#import "UIImage+Size.h"
#import "NSFileManager+TLChat.h"
#import "TLFriendHelper.h"
#import "TLUserHelper.h"
//#import <IQKeyboardManager/IQKeyboardManager.h>
#import "TLMessageManager.h"
#import "TLMessageManager+ConversationRecord.h"
#import <Masonry/Masonry.h>
#import "TLMacros.h"

#import "ParseLiveQuery-Swift.h"
@import Parse;
//@import ParseLiveQuery;
@import Parse.PFQuery;

@interface TLChatBaseViewController() <PFLiveQuerySubscriptionHandling>
@property (nonatomic, strong) PFLiveQueryClient *client;
@property (nonatomic, strong) PFQuery *query;
@property (nonatomic, strong) PFLiveQuerySubscription *subscription; // must use property to hold reference.
@property (nonatomic, strong) TLConversation *converstaion;
@end


@implementation TLChatBaseViewController

- (void)loadView
{
    [super loadView];
    
    [self.view addSubview:self.messageDisplayView];
    [self.view addSubview:self.chatBar];
    
    [self p_addMasonry];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
  
//    self.edgesForExtendedLayout = UIRectEdgeNone; //tempory fix for black gap on top when toggling emoji keyboard.
    self.hidesBottomBarWhenPushed = YES;
    
    [self loadKeyboard];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newChatMessageArrive:) name:@"NewChatMessageReceived" object:nil];
    
    

    
}

- (void)appWillBecomeActive:(NSNotification*)notification {
    [self initLiveQuery];
}

- (void)appWillResignActive:(NSNotification*)notification {
    [self cleanupLiveQuery];
}

- (void)newChatMessageArrive:(NSNotification*)notificaion {
    if ([notificaion.object isEqualToString:self.conversationKey]) {
        [self loadMessagesWithCompletionBlock:^{
            
        } messageIDToIgnore:nil];
    }
}

- (void)loadMessagesWithCompletionBlock:(void(^)(void))completionBlcok messageIDToIgnore:(NSString *)messageIDToIgnore{
    
    self.query = [PFQuery queryWithClassName:kParseClassNameMessage];
    
    
    
    [self.query whereKey:@"dialogKey" equalTo:self.conversationKey]; //livequery doesn't work with pointer
    self.query.limit = 100;
    [self.query orderByDescending:@"createdAt"]; // get recent 1k msgs.
    if (messageIDToIgnore) {
        [self.query whereKey:@"objectId" notEqualTo:messageIDToIgnore];
    }
    if (self.converstaion.lastReadDate) {
        [self.query whereKey:@"createdAt" greaterThan:self.converstaion.lastReadDate];
        
        DLog(@"load message newer than %@", self.converstaion.lastReadDate);
    }
    [self.query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        // do client side sorting
        NSArray * sortedMessages = [objects sortedArrayUsingComparator:^NSComparisonResult(PFObject *  _Nonnull obj1, PFObject *  _Nonnull obj2) {
            return ![obj1[@"createdAt"] isEarlierThanDate:obj2[@"createdAt"]];
        }];
        
        for (PFObject * message in sortedMessages) {
            
            [self processMessageFromServer:message bypassMine:NO];
        }
        
        [[TLMessageManager sharedInstance].conversationStore resetUnreadNumberForConversationByUid:[self.user chat_userID] key:self.conversationKey];
        [[TLMessageManager sharedInstance].conversationStore updateLastReadDateForConversationByUid:[self.user chat_userID] key:self.conversationKey];
        
        if (completionBlcok) {
            completionBlcok();
        }
    }];
    
    
}
- (void)setupLiveQuery:(NSDate *)date {
    

    [self loadMessagesWithCompletionBlock:^{
        
    } messageIDToIgnore:nil];

    
 
    if (self.client) {
        
        DLog(@"live query already setup");
        return;
    }
    
//    if (self.title == nil) {
//        [self.navigationItem setTitle:[NSString stringWithFormat:@"%@",[_partner chat_username]]];
//    }
    self.client = [[PFLiveQueryClient alloc] init];
    
    self.subscription = (PFLiveQuerySubscription*)[self.client subscribeToQuery:self.query withHandler:self];
    
    
//    __weak TLChatBaseViewController * weakSelf = self;
    

    
//    self.subscription = [self.subscription addSubscribeHandler:^(PFQuery<PFObject *> * _Nonnull query) {
//        DLog(@"Subscribed to %@", weakSelf.conversationKey);
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [weakSelf.navigationItem setTitle:[weakSelf.partner chat_username]];
//        });
//
//
//    }];
    
//    self.subscription = [self.subscription addUnsubscribeHandler:^(PFQuery<PFObject *> * _Nonnull query) {
//        NSLog(@"unsubscribed from %@", weakSelf.conversationKey);
//    }];
    
//    self.subscription = [self.subscription addErrorHandler:^(PFQuery<PFObject *> * _Nonnull query, NSError * _Nonnull error) {
//        DLog(@"error occurred! %@", error.localizedDescription);
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [weakSelf.navigationItem setTitle:[NSString stringWithFormat:@"%@(未连接)",[weakSelf.partner chat_username]]];
//        });
//
//    }];
    
//    self.subscription = [self.subscription addEnterHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull object) {
//        NSLog(@"enter");
//    }];
//
//    self.subscription = [self.subscription addEventHandler:^(PFQuery<PFObject *> * _Nonnull query, PFLiveQueryEvent * _Nonnull event) {
//        NSLog(@"event: %ld %@", (long)event.type, event.object[@"message"]);
//    }];
//
//    self.subscription = [self.subscription addDeleteHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull message) {
//        NSLog(@"message deleted: %@ %@",message.createdAt, message.objectId);
//    }];
    
    
    
//    self.subscription = [self.subscription addCreateHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull message) {
//
//        NSLog(@"new message added: %@", message);
//
//        //
//        [weakSelf loadMessagesWithCompletionBlock:^{
//            [weakSelf processMessageFromServer:message bypassMine:YES];
//        } messageIDToIgnore:message.objectId];
//
//
//
//
//    }];
    
//    self.subscription = [self.subscription addErrorHandler:^(PFQuery<PFObject *> * _Nonnull query, NSError * _Nonnull error) {
//        NSLog(@"error: %@", error.localizedDescription);
//
//        [weakSelf.client reconnect];
//    }];
}

# pragma mark - PFLiveQuerySubscriptionHandling
- (void)liveQuery:(PFQuery<PFObject *> *)query didSubscribeInClient:(PFLiveQueryClient *)client {
    DLog(@"Subscribed to %@", self.conversationKey);
    
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self.navigationItem setTitle:[self.partner chat_username]];
    });
}

- (void)liveQuery:(PFQuery<PFObject *> *)query didRecieveEvent:(PFLiveQueryEvent *)event inClient:(PFLiveQueryClient *)client {
    if (event.type == PFLiveQueryEventTypeCreated) {
        PFObject * message = event.object;
        NSLog(@"new message added: %@", message);
        
        //
        [self loadMessagesWithCompletionBlock:^{
            [self processMessageFromServer:message bypassMine:YES];
        } messageIDToIgnore:message.objectId];
        
    }else if (event.type == PFLiveQueryEventTypeCreated) {
        
    }
}

- (void)liveQuery:(PFQuery<PFObject *> *)query didUnsubscribeInClient:(PFLiveQueryClient *)client {
    
    
}

- (void)liveQuery:(PFQuery<PFObject *> *)query didEncounterError:(NSError *)error inClient:(PFLiveQueryClient *)client {
    NSLog(@"error: %@", error.localizedDescription);
    
//    [self.client reconnect];
}

- (void)processMessageFromServer:(PFObject *)message bypassMine:(BOOL)bypassMine{
    
    DLog(@"message received: %@ %@ %@", message.objectId, message[@"message"], message[@"sender"]);
    
    NSDictionary * dict = [message[@"message"] mj_JSONObject];
    
 
    
    if (dict ) {
        if (dict[@"text"]) {
            [self handleTextMessage:message bypassMine:bypassMine];
        }else if (dict[@"time"]) {
            [self handleVoiceMessage:message bypassMine:bypassMine];
        }else if (message[@"thumbnail"]) {
            [self handleImageMessage:message bypassMine:bypassMine];
        }
    }
    
    
}

- (void)handleTextMessage:(PFObject *)message bypassMine:(BOOL)bypassMine{
    NSDictionary * dict = [message[@"message"] mj_JSONObject];
    __weak TLChatBaseViewController * weakSelf = self;
    TLTextMessage *message1 = [[TLTextMessage alloc] init];
    message1.SavedOnServer = YES;
    message1.messageID = message.objectId;
    message1.date = message.createdAt;
    
    TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:message[@"sender"]];
    message1.fromUser = friend;
    
    if ([friend.userID isEqualToString: [TLUserHelper sharedHelper].userID]) {
        message1.ownerTyper = TLMessageOwnerTypeSelf;
    }else{
        message1.ownerTyper = TLMessageOwnerTypeFriend;
    }
    
    message1.userID = [TLUserHelper sharedHelper].userID;
    message1.text = dict[@"text"];
    if (bypassMine && message1.ownerTyper == TLMessageOwnerTypeSelf) {
        
    }else{
        if ([self isLocalMessage:message] || [self hasDownloaded:message]) {
            
        }else{
            [weakSelf receivedMessage:message1];
        }
            
    }
}

- (BOOL)isLocalMessage:(PFObject*)message {
    if (message[@"localID"]) {
        
        NSArray * matches = [self.messageDisplayView.data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"messageID == %@", message[@"localID"]]];
        return (matches.count > 0);
    }
    return NO;
}

- (BOOL)hasDownloaded:(PFObject*)message {
    if (message.objectId) {
        
        NSArray * matches = [self.messageDisplayView.data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"messageID == %@", message.objectId]];
        return (matches.count > 0);
    }
    return NO;
}


- (void)handleImageMessage:(PFObject *)message bypassMine:(BOOL)bypassMine{
    __weak TLChatBaseViewController * weakSelf = self;
    NSDictionary * dict = [message[@"message"] mj_JSONObject];
    
    TLImageMessage *message1 = [[TLImageMessage alloc] init];
    message1.SavedOnServer = YES;
    message1.messageID = message.objectId;
    message1.date = message.createdAt;
    
    TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:message[@"sender"]];
    message1.fromUser = friend;
    
    if ([friend.userID isEqualToString: [TLUserHelper sharedHelper].userID]) {
        message1.ownerTyper = TLMessageOwnerTypeSelf;
    }else{
        message1.ownerTyper = TLMessageOwnerTypeFriend;
    }
    
    message1.userID = [TLUserHelper sharedHelper].userID;
    
    PFFile * file = message[@"thumbnail"];
    if (dict[@"w"] && dict[@"h"]) {
        message1.imageSize = CGSizeMake([dict[@"w"] floatValue], [dict[@"h"] floatValue]);
    }
    
//    NSString *imageName = [NSString stringWithFormat:@"thumb-%@", dict[@"path"]];
//    NSString *imagePath = [NSFileManager pathUserChatImage:imageName];
 
    message1.thumbnailImageURL = file.url;
//    message1.thumbnailImagePath = imageName; //no path needed here, cell will prefix it when rendering
    PFFile * attachment =  message[@"attachment"];
    message1.imageURL = attachment.url;
    
    if (bypassMine && message1.ownerTyper == TLMessageOwnerTypeSelf) {
        
    }else{
        if ([self isLocalMessage:message] || [self hasDownloaded:message]) {
            
        }else{
            [weakSelf receivedMessage:message1];
        }
    }
    
//    if (file && ![file isKindOfClass:[NSNull class]]) {
//
//
//        [file getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error) {
//            if (!error) {
//
//                if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
//                    [[NSFileManager defaultManager] createFileAtPath:imagePath contents:imageData attributes:nil];
//                }
//
//
//            } else {
//
//            }
//        }];
//    }
    
    
}

- (void)handleVoiceMessage:(PFObject *)message bypassMine:(BOOL)bypassMine{
    __weak TLChatBaseViewController * weakSelf = self;
    NSDictionary * dict = [message[@"message"] mj_JSONObject];
    
    TLVoiceMessage *message1 = [[TLVoiceMessage alloc] init];
    message1.SavedOnServer = YES;
    message1.messageID = message.objectId;
    message1.date = message.createdAt;

    TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:message[@"sender"]];
    message1.fromUser = friend;
    
    if ([friend.userID isEqualToString: [TLUserHelper sharedHelper].userID]) {
        message1.ownerTyper = TLMessageOwnerTypeSelf;
    }else{
        message1.ownerTyper = TLMessageOwnerTypeFriend;
    }
    
    message1.userID = [TLUserHelper sharedHelper].userID;
    NSString *fileName = dict[@"path"];
    NSString *filePath = [NSFileManager pathUserChatVoice:fileName];

    
    message1.recFileName = fileName;
    message1.time = [dict[@"time"] floatValue];
    message1.msgStatus = TLVoiceMessageStatusNormal;
    
    if (bypassMine && message1.ownerTyper == TLMessageOwnerTypeSelf) {
        
    }else{
        if ([self isLocalMessage:message] || [self hasDownloaded:message]) {
            
        }else{
            [weakSelf receivedMessage:message1];
        }
    }
    
    PFFile * file = message[@"attachment"];
 
    if (file && ![file isKindOfClass:[NSNull class]]) {
        [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
            if (!error) {
                
                if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                    [[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil];
                }
 
            } else {
                
            }
        }];
    }
    
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    
//    [[IQKeyboardManager sharedManager] setEnableAutoToolbar:NO]; // conflict with chat? has to set this to no.
    
    [self initLiveQuery];
    
}

- (void)initLiveQuery {
    [[TLMessageManager sharedInstance] refreshConversationRecord];
    
    [[TLMessageManager sharedInstance] conversationRecord:^(NSArray *data) {
        NSDate * lastReadDate = nil;
        for (TLConversation *conversation in data) {
            if ([conversation.partnerID isEqualToString:self.partner.chat_userID]) {
                
                lastReadDate = conversation.lastReadDate;
                self.converstaion = conversation;
                break;
            }
        }
        
        [self setupLiveQuery:lastReadDate];
    }];
    

}

- (void)cleanupLiveQuery {
    if (self.client) {
        [self.client unsubscribeFromQuery:self.query];
//        [self.client disconnect];
        self.client = nil;
    }
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[TLAudioPlayer sharedAudioPlayer] stopPlayingAudio];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
//    [[IQKeyboardManager sharedManager] setEnableAutoToolbar:YES];
    

    [self cleanupLiveQuery];
}

- (void)dealloc
{
    [[TLMoreKeyboard keyboard] dismissWithAnimation:NO];
    [[TLEmojiKeyboard keyboard] dismissWithAnimation:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#ifdef DEBUG_MEMERY
    NSLog(@"dealloc ChatBaseVC");
#endif
}

#pragma mark - # Public Methods
- (void)setPartner:(id<TLChatUserProtocol>)partner
{
    if (_partner && [[_partner chat_userID] isEqualToString:[partner chat_userID]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messageDisplayView scrollToBottomWithAnimation:NO];
        });
        return;
    }
    _partner = partner;
    
    if (self.title == nil) {
        [self.navigationItem setTitle:[NSString stringWithFormat:@"%@",[_partner chat_username]]];
    }
    
    

    NSString * key = @"";
    if ([_partner isKindOfClass:[TLGroup class]]) {
        key = [(TLGroup*)partner groupID];
    }else{
        key = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:[_partner chat_userID] myId:[[TLUserHelper sharedHelper] userID] ];
    }
    [self setConversationKey:key];
    
    [self resetChatVC];
}

- (void)setConversationKey:(NSString *)conversationKey {
    
    _conversationKey = conversationKey;
    
    if (_partner == nil) {
        
        NSArray * users = [conversationKey componentsSeparatedByString:@":"];
        if (users.count > 1) {
            NSArray * matches = [users filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@", [TLUserHelper sharedHelper].userID]];
            if (matches.count > 0) {
                NSString * friendID = matches.firstObject;
                TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:friendID];
                
                self.partner = (id<TLChatUserProtocol>)friend;
            }
        }else{
            
            // GROUP
            
            TLGroup * group = [[TLFriendHelper sharedFriendHelper] getGroupInfoByGroupID:conversationKey];
            self.partner = (id<TLChatUserProtocol>)group;
        }
        
    }
}

- (void)setChatMoreKeyboardData:(NSMutableArray *)moreKeyboardData
{
    [self.moreKeyboard setChatMoreKeyboardData:moreKeyboardData];
}

- (void)setChatEmojiKeyboardData:(NSMutableArray *)emojiKeyboardData
{
    [self.emojiKeyboard setEmojiGroupData:emojiKeyboardData];
}

- (void)resetChatVC
{
    NSString *chatViewBGImage;
    if (self.partner) {
        chatViewBGImage = [[NSUserDefaults standardUserDefaults] objectForKey:[@"CHAT_BG_" stringByAppendingString:[self.partner chat_userID]]];
    }
    if (chatViewBGImage == nil) {
        chatViewBGImage = [[NSUserDefaults standardUserDefaults] objectForKey:@"CHAT_BG_ALL"];
        if (chatViewBGImage == nil) {
            [self.view setBackgroundColor:[UIColor colorGrayCharcoalBG]];
        }
        else {
            NSString *imagePath = [NSFileManager pathUserChatBackgroundImage:chatViewBGImage];
            UIImage *image = [UIImage imageNamed:imagePath];
            [self.view setBackgroundColor:[UIColor colorWithPatternImage:image]];
        }
    }
    else {
        NSString *imagePath = [NSFileManager pathUserChatBackgroundImage:chatViewBGImage];
        UIImage *image = [UIImage imageNamed:imagePath];
        [self.view setBackgroundColor:[UIColor colorWithPatternImage:image]];
    }
    
    [self resetChatTVC];
}

/**
 *  发送图片消息
 */
- (void)sendImageMessage:(UIImage *)image
{
    NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
    NSString *imageName = [NSString stringWithFormat:@"%lf.jpg", [NSDate date].timeIntervalSince1970];
    NSString *imagePath = [NSFileManager pathUserChatImage:imageName];
    [[NSFileManager defaultManager] createFileAtPath:imagePath contents:imageData attributes:nil];
    
    TLImageMessage *message = [[TLImageMessage alloc] init];
    message.fromUser = self.user;
    message.ownerTyper = TLMessageOwnerTypeSelf;
    message.imagePath = imageName;
    
    NSString *thumbImageName = [NSString stringWithFormat:@"thumb-%@", imageName];
    NSString *thumbImagePath = [NSFileManager pathUserChatImage:thumbImageName];
    
    [[NSFileManager defaultManager] createFileAtPath:thumbImagePath contents:imageData attributes:nil];
    
    
    message.thumbnailImagePath = thumbImageName;
    message.imageSize = image.size; //png size doesn't include oritation info.
    message.imageData = imageData;
    [self sendMessage:message];
    

}

#pragma mark - # Private Methods
- (void)p_addMasonry
{
    [self.messageDisplayView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.and.left.and.right.mas_equalTo(self.view);
        make.bottom.mas_equalTo(self.chatBar.mas_top);
    }];
    [self.chatBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.and.right.and.bottom.mas_equalTo(self.view);
        make.height.mas_greaterThanOrEqualTo(TABBAR_HEIGHT);
    }];
    [self.view layoutIfNeeded];
}

#pragma mark - # Getter
- (TLChatMessageDisplayView *)messageDisplayView
{
    if (_messageDisplayView == nil) {
        _messageDisplayView = [[TLChatMessageDisplayView alloc] init];
        [_messageDisplayView setDelegate:self];
    }
    return _messageDisplayView;
}

- (TLChatBar *)chatBar
{
    if (_chatBar == nil) {
        _chatBar = [[TLChatBar alloc] init];
        [_chatBar setDelegate:self];
    }
    return _chatBar;
}

- (TLEmojiDisplayView *)emojiDisplayView
{
    if (_emojiDisplayView == nil) {
        _emojiDisplayView = [[TLEmojiDisplayView alloc] init];
    }
    return _emojiDisplayView;
}

- (TLImageExpressionDisplayView *)imageExpressionDisplayView
{
    if (_imageExpressionDisplayView == nil) {
        _imageExpressionDisplayView = [[TLImageExpressionDisplayView alloc] init];
    }
    return _imageExpressionDisplayView;
}

- (TLRecorderIndicatorView *)recorderIndicatorView
{
    if (_recorderIndicatorView == nil) {
        _recorderIndicatorView = [[TLRecorderIndicatorView alloc] init];
    }
    return _recorderIndicatorView;
}

@end
