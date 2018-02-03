//
//  TLConversationLiveQueryHandler.h
//  UNI
//
//  Created by Frank Mao on 2018-02-02.
//  Copyright © 2018 Mazoic Technologies Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Parse;
@import ParseLiveQuery;
@import Parse.PFQuery;

@interface TLConversationLiveQueryHandler : NSObject  <PFLiveQuerySubscriptionHandling>

+ (TLConversationLiveQueryHandler *)sharedHandler;


@end
