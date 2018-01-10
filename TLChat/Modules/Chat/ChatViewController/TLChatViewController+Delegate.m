//
//  TLChatViewController+Delegate.m
//  TLChat
//
//  Created by 李伯坤 on 16/3/17.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLChatViewController+Delegate.h"
#import "TLExpressionViewController.h"
#import "TLMyExpressionViewController.h"
#import "TLFriendDetailViewController.h"
#import <MWPhotoBrowser/MWPhotoBrowser.h>
#import "NSFileManager+TLChat.h"
#import "TLUIManager.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface TLChatViewController ()

@end

@implementation TLChatViewController (Delegate)

#pragma mark - Delegate -
//MARK: TLMoreKeyboardDelegate
- (void)moreKeyboard:(id)keyboard didSelectedFunctionItem:(TLMoreKeyboardItem *)funcItem
{
    if (funcItem.type == TLMoreKeyboardItemTypeCamera || funcItem.type == TLMoreKeyboardItemTypeImage) {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        if (funcItem.type == TLMoreKeyboardItemTypeCamera) {
            if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                [imagePickerController setSourceType:UIImagePickerControllerSourceTypeCamera];
            }
            else {
                [TLUIUtility showAlertWithTitle:@"错误" message:@"相机初始化失败"];
                return;
            }
        }
        else {
            [imagePickerController setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        }
        [self presentViewController:imagePickerController animated:YES completion:nil];
        __weak typeof(self) weakSelf = self;
        [imagePickerController.rac_imageSelectedSignal subscribeNext:^(id x) {
            [imagePickerController dismissViewControllerAnimated:YES completion:^{
                UIImage *image = [x objectForKey:UIImagePickerControllerOriginalImage];
                [weakSelf sendImageMessage:image];
            }];
        } completed:^{
            [imagePickerController dismissViewControllerAnimated:YES completion:nil];
        }];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:[NSString stringWithFormat:@"选中”%@“ 按钮", funcItem.title] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];
    }
}

//MARK: TLEmojiKeyboardDelegate
- (void)emojiKeyboardEmojiEditButtonDown
{
    TLExpressionViewController *expressionVC = [[TLExpressionViewController alloc] init];
    UINavigationController *navC = [[UINavigationController alloc] initWithRootViewController:expressionVC];
    [self presentViewController:navC animated:YES completion:nil];
}

- (void)emojiKeyboardMyEmojiEditButtonDown
{
    TLMyExpressionViewController *myExpressionVC = [[TLMyExpressionViewController alloc] init];
    UINavigationController *navC = [[UINavigationController alloc] initWithRootViewController:myExpressionVC];
    [self presentViewController:navC animated:YES completion:nil];
}

//MARK: TLChatViewControllerProxy
- (void)didClickedUserAvatar:(TLUser *)user
{
//    TLFriendDetailViewController *detailVC = [[TLFriendDetailViewController alloc] init];
//    [detailVC setUser:user];
//    [self setHidesBottomBarWhenPushed:YES];
//    [self.navigationController pushViewController:detailVC animated:YES];
    
//    self.userId = [NSString stringWithFormat:@"%ld", [[dict valueForKey:@"userId"] integerValue]];
//    self.name = [dict stringForKey:@"name"];
//    self.headerIcon = [dict stringForKey:@"headerIcon"];
//    self.friendState =[dict integerForKey:@"isFriend"];
    
//    HSStudentUserInfo * userInfo = [[HSStudentUserInfo alloc] initWithDict:
//                                    @{@"userId":user.userID,
//                                      @"name":user.username,
//                                      @"headerIcon":user.avatarURL ?: @"",
//                                      @"isFriend":@(YES)
//                                      }]; // TODO: handle non-friend chat.
    if ([[UIApplication sharedApplication].delegate respondsToSelector:@selector(openUserDetails:navigationController:)]) {
        [[UIApplication sharedApplication].delegate performSelector:@selector(openUserDetails:navigationController:) withObject:user withObject:self.navigationController];
    }
    // place this code in appdelegate if use default wechat style user details profile viewer.
//    [[TLUIManager sharedUIManager]  openUserDetails:user navigationController:self.navigationController];
    
}

- (void)didClickedImageMessages:(NSArray *)imageMessages atIndex:(NSInteger)index
{
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (TLMessage *message in imageMessages) {
        NSURL *url;
        if ([(TLImageMessage *)message imagePath]) {
            NSString *imagePath = [NSFileManager pathUserChatImage:[(TLImageMessage *)message imagePath]];
            url = [NSURL fileURLWithPath:imagePath];
        }
        else {
            url = TLURL([(TLImageMessage *)message imageURL]);
        }
  
        MWPhoto *photo = [MWPhoto photoWithURL:url];
        [data addObject:photo];
    }
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:data];
    [browser setDisplayNavArrows:YES];
    [browser setCurrentPhotoIndex:index];
    UINavigationController *broserNavC = [[UINavigationController alloc] initWithRootViewController:browser];
    [self presentViewController:broserNavC animated:NO completion:nil];
}
@end
