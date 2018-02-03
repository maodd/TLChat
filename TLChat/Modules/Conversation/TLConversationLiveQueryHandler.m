//
//  TLConversationLiveQueryHandler.m
//  UNI
//
//  Created by Frank Mao on 2018-02-02.
//  Copyright © 2018 Mazoic Technologies Inc. All rights reserved.
//

#import "TLConversationLiveQueryHandler.h"

@implementation TLConversationLiveQueryHandler

static TLConversationLiveQueryHandler *handler = nil;


+ (TLConversationLiveQueryHandler *)sharedHandler
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handler = [[TLConversationLiveQueryHandler alloc] init];
        
        
    });
    return handler;
}


# pragma mark - PFLiveQuerySubscriptionHandling
- (void)liveQuery:(PFQuery<PFObject *> *)query didSubscribeInClient:(PFLiveQueryClient *)client {
    DLog(@"Subscribed to client ");
    
}

- (void)liveQuery:(PFQuery<PFObject *> *)query didUnsubscribeInClient:(PFLiveQueryClient *)client {
    
}

- (void)liveQuery:(PFQuery<PFObject *> *)query didRecieveEvent:(PFLiveQueryEvent *)event inClient:(PFLiveQueryClient *)client {
    if (event.type == PFLiveQueryEventTypeCreated) {
//        PFObject * message = event.object;
//        [self processMessageFromServer:message bypassMine:YES];
    }
}

- (void)liveQuery:(PFQuery<PFObject *> *)query didEncounterError:(NSError *)error inClient:(PFLiveQueryClient *)client {
    NSLog(@"livequery error %@", error.localizedDescription);
    
}

@end
