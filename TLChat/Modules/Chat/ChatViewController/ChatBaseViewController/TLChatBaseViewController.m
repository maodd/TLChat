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
#import <IQKeyboardManager/IQKeyboardManager.h>
#import "TLMessageManager.h"
#import "TLMessageManager+ConversationRecord.h"

@import Parse;
@import ParseLiveQuery;
@import Parse.PFQuery;

@interface TLChatBaseViewController()
@property (nonatomic, strong) PFLiveQueryClient *client;
@property (nonatomic, strong) PFQuery *query;
@property (nonatomic, strong) PFLiveQuerySubscription *subscription; // must use property to hold reference.
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
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.hidesBottomBarWhenPushed = YES;
    
    [self loadKeyboard];
    
   
    
}

- (void)setupLiveQuery:(NSDate *)date {
    
    self.client = [[PFLiveQueryClient alloc] init];
    
    self.query = [PFQuery queryWithClassName:kParseClassNameMessage];
    
    
    
    [self.query whereKey:@"dialogKey" equalTo:self.conversationKey]; //livequery doesn't work with pointer
    
    [self.query orderByAscending:@"createdAt"];
    if (date) {
        [self.query whereKey:@"createdAt" greaterThan:date];
    }
    [self.query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        for (PFObject * message in [objects sortedArrayUsingComparator:^NSComparisonResult(PFObject *  _Nonnull obj1, PFObject *  _Nonnull obj2) {
            return [obj1[@"createdAt"] isEarlierThanDate:obj2[@"createdAt"]];
        }]) {
            
            [self processMessageFromServer:message bypassMine:NO];
        }
    }];
    
 
    
    
    self.subscription = [self.client  subscribeToQuery:self.query];
    
    
    self.subscription = [self.subscription addSubscribeHandler:^(PFQuery<PFObject *> * _Nonnull query) {
        DLog(@"Subscribed");
    }];
    
    self.subscription = [self.subscription addUnsubscribeHandler:^(PFQuery<PFObject *> * _Nonnull query) {
        NSLog(@"unsubscribed");
    }];
    
    self.subscription = [self.subscription addEnterHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull object) {
        NSLog(@"enter");
    }];
    
    self.subscription = [self.subscription addEventHandler:^(PFQuery<PFObject *> * _Nonnull query, PFLiveQueryEvent * _Nonnull event) {
        NSLog(@"event: %@", event);
    }];
    
    self.subscription = [self.subscription addDeleteHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull message) {
        NSLog(@"message deleted: %@ %@",message.createdAt, message.objectId);
    }];
    
    
    __weak TLChatBaseViewController * weakSelf = self;
    self.subscription = [self.subscription addCreateHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull message) {
        
        NSLog(@"new message added: %@", message);
        [weakSelf processMessageFromServer:message bypassMine:YES];
        
        
    }];
    
    self.subscription = [self.subscription addErrorHandler:^(PFQuery<PFObject *> * _Nonnull query, NSError * _Nonnull error) {
        NSLog(@"error: %@", error.localizedDescription);
        
        [weakSelf.client reconnect];
    }];
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
    if ([[self.user chat_userID] isEqualToString: message[@"sender"]]) {
        message1.fromUser = weakSelf.user;
        message1.ownerTyper = TLMessageOwnerTypeSelf;
        
    }else{
        if ([self.partner isKindOfClass:[TLGroup class]]) {
            TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:message[@"sender"]];
            message1.fromUser = friend;
        }else{
            message1.fromUser = self.partner;
        }
        
        message1.ownerTyper = TLMessageOwnerTypeFriend;
    }
    
    message1.userID = message[@"sender"];
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
    if (message[@"messageID"]) {
        
        NSArray * matches = [self.messageDisplayView.data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"messageID == %@", message[@"messageID"]]];
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
    if ([[self.user chat_userID]  isEqualToString: message[@"sender"]]) {
        message1.fromUser = weakSelf.user;
        message1.ownerTyper = TLMessageOwnerTypeSelf;
        
    }else{
        if ([self.partner isKindOfClass:[TLGroup class]]) {
            TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:message[@"sender"]];
            message1.fromUser = friend;
        }else{
            message1.fromUser = self.partner;
        }

        message1.ownerTyper = TLMessageOwnerTypeFriend;
    }
    message1.userID = message[@"sender"];
    
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
    if ([[self.user chat_userID]  isEqualToString: message[@"sender"]]) {
        message1.fromUser = weakSelf.user;
        message1.ownerTyper = TLMessageOwnerTypeSelf;
        
    }else{
        
        if ([self.partner isKindOfClass:[TLGroup class]]) {
            TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:message[@"sender"]];
            message1.fromUser = friend;
        }else{
            message1.fromUser = self.partner;
        }
        

        message1.ownerTyper = TLMessageOwnerTypeFriend;
    }
    message1.userID = message[@"sender"];
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
    
    [[IQKeyboardManager sharedManager] setEnableAutoToolbar:NO]; // conflict with chat? has to set this to no.
    
    [[TLMessageManager sharedInstance] refreshConversationRecord];
    
    [[TLMessageManager sharedInstance] conversationRecord:^(NSArray *data) {
        NSDate * lastMsgDate = nil;
        for (TLConversation *conversation in data) {
            if ([conversation.partnerID isEqualToString:self.partner.chat_userID]) {
                
                lastMsgDate = conversation.date;
                break;
            }
        }
        
        [self setupLiveQuery:lastMsgDate];
    }];
    
     [[TLMessageManager sharedInstance].conversationStore resetUnreadNumberForConversationByUid:[self.user chat_userID] fid:self.conversationKey];
}



- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[TLAudioPlayer sharedAudioPlayer] stopPlayingAudio];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
//    [[IQKeyboardManager sharedManager] setEnableAutoToolbar:YES];
    
    if (self.client) {
        [self.client unsubscribeFromQuery:self.query];
        [self.client disconnect];
        self.client = nil;
    }
    
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
    [self.navigationItem setTitle:[_partner chat_username]];
    

    NSString * key = @"";
    if ([_partner isKindOfClass:[TLGroup class]]) {
        key = [(TLGroup*)partner groupID];
    }else{
        key = [[TLFriendHelper sharedFriendHelper] makeDialogNameForFriend:[_partner chat_userID] myId:[[TLUserHelper sharedHelper] userID] ];
    }
    [self setConversationKey:key];
    
    [self resetChatVC];
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
