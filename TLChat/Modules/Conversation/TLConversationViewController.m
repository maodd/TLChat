//
//  TLConversationViewController.m
//  TLChat
//
//  Created by 李伯坤 on 16/1/23.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLConversationViewController.h"
#import "TLConversationViewController+Delegate.h"
#import "TLSearchController.h"
#import <AFNetworking/AFNetworking.h>
//#import "TLAppDelegate.h"
#import "TLFriendHelper.h"
#import "TLUserHelper.h"
#import "TLFriendDataLoader.h"
#import "TLGroupDataLoader.h"

#import "TLMessageManager+ConversationRecord.h"
#import "TLMacros.h"



@interface TLConversationViewController ()

@property (nonatomic, strong) UIImageView *scrollTopView;

@property (nonatomic, strong) TLSearchController *searchController;

@property (nonatomic, strong) TLAddMenuView *addMenuView;


@end

@implementation TLConversationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self.navigationItem setTitle:@"聊天"];
    
    [self p_initUI];        // 初始化界面UI
    [self registerCellClass];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [[TLMessageManager sharedInstance] setConversationDelegate:self];
   
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChange:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
    
    if ([TLUserHelper sharedHelper].isLogin) {
        [TLFriendHelper sharedFriendHelper]; // force a friend data load.
    }
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kAKUserLoggedInNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [TLFriendHelper sharedFriendHelper]; // force a friend data load.
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kAKUserLoggedOutNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [[TLFriendHelper sharedFriendHelper] reset];
        [self updateConversationData];
        
      
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateConversationData) name:kAKFriendsAndGroupDataUpdateNotification object:nil];
    

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newChatMessageArrive:) name:@"NewChatMessageReceived" object:nil];
    
    self.definesPresentationContext = YES;
}

- (void)newChatMessageArrive:(NSNotification*)notificaion {
    
    
    __weak TLConversationViewController * weakSelf = self;
    NSString * conversationKey = notificaion.object;
    if (conversationKey) {
        // friends
        NSArray * users = [conversationKey componentsSeparatedByString:@":"];
        if (users.count > 1) {
            NSArray * matches = [users filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@", [TLUserHelper sharedHelper].userID]];
            if (matches.count > 0) {
                NSString * friendID = matches.firstObject;
                TLUser * friend = [[TLFriendHelper sharedFriendHelper] getFriendInfoByUserID:friendID];
                
                [[TLFriendDataLoader sharedFriendDataLoader] createFriendDialogWithLatestMessage:friend completionBlock:^{
                    [weakSelf updateConversationData];
                }];
            }
        }else{
            
            // GROUP
            
            TLGroup * group = [[TLFriendHelper sharedFriendHelper] getGroupInfoByGroupID:conversationKey];
            
            
            [[TLGroupDataLoader sharedGroupDataLoader] createCourseDialogWithLatestMessage:group completionBlock:^{
               [weakSelf updateConversationData];
            }];
        }
    }
    
    [self updateConversationData]; 
    
    
    
}



- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([TLUserHelper sharedHelper].isLogin) {
        [self updateConversationData];  // to update conversation lastes message whenver back to this screen
    }

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.addMenuView.isShow) {
        [self.addMenuView dismiss];
    }
    
//    if (self.client) {
//        [self.client unsubscribeFromQuery:self.query];
//        [self.client disconnect];
//        self.client = nil;
//
//        _currentKeys = nil;
//    }
}

#pragma mark - Event Response
- (void)rightBarButtonDown:(UIBarButtonItem *)sender
{
    if (self.addMenuView.isShow) {
        [self.addMenuView dismiss];
    }
    else {
        [self.addMenuView showInView:self.navigationController.view];
    }
}

// 网络情况改变
- (void)networkStatusChange:(NSNotification *)noti
{
    AFNetworkReachabilityStatus status = [noti.userInfo[@"AFNetworkingReachabilityNotificationStatusItem"] longValue];
    switch (status) {
        case AFNetworkReachabilityStatusReachableViaWiFi:
        case AFNetworkReachabilityStatusReachableViaWWAN:
        case AFNetworkReachabilityStatusUnknown:
//            [self.navigationItem setTitle:@"聊天"];
            break;
        case AFNetworkReachabilityStatusNotReachable:
//            [self.navigationItem setTitle:@"聊天(未连接)"];
            break;
        default:
            break;
    }
}

#pragma mark - Private Methods -
- (void)p_initUI
{
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self.tableView setBackgroundColor:[UIColor whiteColor]];
    //    [self.tableView setTableHeaderView:self.searchController.searchBar]; //TODO: change to search in chat, not in all friends.
    [self.tableView addSubview:self.scrollTopView];
    [self.scrollTopView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.tableView);
        make.bottom.mas_equalTo(self.tableView.mas_top).mas_offset(-35);
    }];

    // TODO: fututure features
//    UIBarButtonItem *rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_add"] style:UIBarButtonItemStyleDone target:self action:@selector(rightBarButtonDown:)];
//    [self.navigationItem setRightBarButtonItem:rightBarButtonItem];
}



#pragma mark - Getter -
- (TLSearchController *) searchController
{
    if (_searchController == nil) {
        _searchController = [[TLSearchController alloc] initWithSearchResultsController:self.searchVC];
        [_searchController setSearchResultsUpdater:self.searchVC];
        [_searchController.searchBar setPlaceholder:@"搜索"];
        [_searchController.searchBar setDelegate:self];
        [_searchController setShowVoiceButton:YES];
        _searchController.hidesNavigationBarDuringPresentation = NO;
    }
    return _searchController;
}

- (TLFriendSearchViewController *) searchVC
{
    if (_searchVC == nil) {
        _searchVC = [[TLFriendSearchViewController alloc] init];
    }
    return _searchVC;
}

- (UIImageView *)scrollTopView
{
    if (_scrollTopView == nil) {
        _scrollTopView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"nav_menu_radar"]];
    }
    return _scrollTopView;
}

- (TLAddMenuView *)addMenuView
{
    if (_addMenuView == nil) {
        _addMenuView = [[TLAddMenuView alloc] init];
        [_addMenuView setDelegate:self];
    }
    return _addMenuView;
}

@end
