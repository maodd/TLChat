//
//  TLUserHelper.m
//  TLChat
//
//  Created by 李伯坤 on 16/2/6.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLUserHelper.h"
#import "TLDBUserStore.h"
#import "TLMacros.h"

@import Parse;

@implementation TLUserHelper
@synthesize user = _user;

+ (TLUserHelper *)sharedHelper
{
    static TLUserHelper *helper;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        helper = [[TLUserHelper alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:kAKUserLoggedOutNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            helper.user = nil;
        }];
    });
    return helper;
}

- (void)loginTestAccount
{
    TLUser *user = [[TLUser alloc] init];
    user.userID = @"1000";
    user.avatarURL = @"http://p1.qq181.com/cms/120506/2012050623111097826.jpg";
    user.nikeName = @"李伯坤";
    user.username = @"li-bokun";
    user.detailInfo.qqNumber = @"1159197873";
    user.detailInfo.email = @"libokun@126.com";
    user.detailInfo.location = @"山东 滨州";
    user.detailInfo.sex = @"男";
    user.detailInfo.motto = @"Hello world!";
    user.detailInfo.momentsWallURL = @"http://img06.tooopen.com/images/20160913/tooopen_sy_178786212749.jpg";

    [self setUser:user];
}

- (void)setUser:(TLUser *)user
{
 
    
    _user = user;
    TLDBUserStore *userStore = [[TLDBUserStore alloc] init];
    if (![userStore updateUser:user]) {
        DDLogError(@"登录数据存库失败");
        
  
    }


}
- (TLUser *)user
{
    if (!_user) {
        if (self.userID.length > 0) {
            TLDBUserStore *userStore = [[TLDBUserStore alloc] init];
            _user = [userStore userByID:self.userID];
 
 
            [[PFUser currentUser] fetch];
        
            _user = [TLUser new];
            _user.userID = self.userID;
            _user.username = [PFUser currentUser].username;
            _user.nikeName = [PFUser currentUser][kParseUserClassAttributeNickname] ?: _user.username;
            
            
            NSString * avatarKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TLChatUserAvatarFieldName"];
            
            NSString * avatarFieldName = avatarKey ?: kParseUserClassAttributeAvatar;
            
            PFFile * file = [PFUser currentUser][avatarFieldName];
            if (file) {
                _user.avatarURL = file.url;
            }

            
            
            [self setUser:_user];
        }
    
    
    }
    return _user;
}

- (NSString *)userID
{
    return [PFUser currentUser].objectId;
}

- (BOOL)isLogin
{
    return [PFUser currentUser].objectId.length > 0;
}

@end
