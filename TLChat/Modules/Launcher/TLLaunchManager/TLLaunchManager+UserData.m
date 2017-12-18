//
//  TLLaunchManager+UserData.m
//  TLChat
//
//  Created by 李伯坤 on 2017/9/19.
//  Copyright © 2017年 李伯坤. All rights reserved.
//

#import "TLLaunchManager+UserData.h"
//#import "TLWalletViewController.h"
#import "TLExpressionProxy.h"
#import "TLEmojiGroup.h"
#import "TLExpressionHelper.h"
#import <TLKit/TLKit.h>
#import "TLMacros.h"
//#import "TLMineEventStatistics.h"

@implementation TLLaunchManager (UserData)

- (void)initUserData
{
    NSNumber *lastRunDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastRunDate"];
    
    if (lastRunDate == nil) {
        [TLUIUtility showAlertWithTitle:@"提示" message:@"首次启动App，是否随机下载两组个性表情包，稍候也可在“我的”-“表情”中选择下载。" cancelButtonTitle:@"取消" otherButtonTitles:@[@"确定"] actionHandler:^(NSInteger buttonIndex) {
            if (buttonIndex == 1) {
                [self downloadDefaultExpression];
            }
        }];
    }
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:lastRunDate.doubleValue];
    NSNumber *sponsorStatus = [[NSUserDefaults standardUserDefaults] objectForKey:@"sponsorStatus"];
    NSLog(@"今天第%ld次进入", (long)sponsorStatus.integerValue);
  
}

/// 下载默认表情包
- (void)downloadDefaultExpression
{
    [TLUIUtility showLoading:nil];
    __block NSInteger count = 0;
    __block NSInteger successCount = 0;
    TLExpressionProxy *proxy = [[TLExpressionProxy alloc] init];
    TLEmojiGroup *group = [[TLEmojiGroup alloc] init];
    group.groupID = @"241";
    group.groupName = @"婉转的骂人";
    group.groupIconURL = [IEXPRESSION_HOST_URL stringByAppendingString:@"expre/downloadsuo.do?pId=10790"];
    group.groupInfo = @"婉转的骂人";
    group.groupDetailInfo = @"婉转的骂人表情，慎用";
    [proxy requestExpressionGroupDetailByGroupID:group.groupID pageIndex:1 success:^(id data) {
        group.data = data;
        [[TLExpressionHelper sharedHelper] downloadExpressionsWithGroupInfo:group progress:^(CGFloat progress) {
            
        } success:^(TLEmojiGroup *group) {
            BOOL ok = [[TLExpressionHelper sharedHelper] addExpressionGroup:group];
            if (!ok) {
                DDLogError(@"表情存储失败！");
            }
            else {
                successCount ++;
            }
            count ++;
            if (count == 2) {
                [TLUIUtility showSuccessHint:[NSString stringWithFormat:@"成功下载%ld组表情！", (long)successCount]];
            }
        } failure:^(TLEmojiGroup *group, NSString *error) {
            
        }];
    } failure:^(NSString *error) {
        count ++;
        if (count == 2) {
            [TLUIUtility showErrorHint:[NSString stringWithFormat:@"成功下载%ld组表情！", (long)successCount]];
        }
    }];
    
    
    TLEmojiGroup *group1 = [[TLEmojiGroup alloc] init];
    group1.groupID = @"223";
    group1.groupName = @"王锡玄";
    group1.groupIconURL = [IEXPRESSION_HOST_URL stringByAppendingString:@"expre/downloadsuo.do?pId=10482"];
    group1.groupInfo = @"王锡玄 萌娃 冷笑宝宝";
    group1.groupDetailInfo = @"韩国萌娃，冷笑宝宝王锡玄表情包";
    [proxy requestExpressionGroupDetailByGroupID:group1.groupID pageIndex:1 success:^(id data) {
        group1.data = data;
        [[TLExpressionHelper sharedHelper] downloadExpressionsWithGroupInfo:group1 progress:^(CGFloat progress) {
            
        } success:^(TLEmojiGroup *group) {
            BOOL ok = [[TLExpressionHelper sharedHelper] addExpressionGroup:group];
            if (!ok) {
                DDLogError(@"表情存储失败！");
            }
            else {
                successCount ++;
            }
            count ++;
            if (count == 2) {
                [TLUIUtility showSuccessHint:[NSString stringWithFormat:@"成功下载%ld组表情！", (long)successCount]];
            }
        } failure:^(TLEmojiGroup *group, NSString *error) {
            
        }];
    } failure:^(NSString *error) {
        count ++;
        if (count == 2) {
            [TLUIUtility showSuccessHint:[NSString stringWithFormat:@"成功下载%ld组表情！", (long)successCount]];
        }
    }];
}


@end
