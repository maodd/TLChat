//
//  TLAudioPlayer.m
//  TLChat
//
//  Created by 李伯坤 on 16/7/12.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry/Masonry.h>
#import <TLKit/TLKit.h>
#import "UIColor+TLChat.h"
#import "UIFont+TLChat.h"
#import "TLMacros.h"
@interface TLAudioPlayer() <AVAudioPlayerDelegate>

@property (nonatomic, strong) void (^ completeBlock)(BOOL finished);

@property (nonatomic, strong) AVAudioPlayer *player;

@end

@implementation TLAudioPlayer

+ (TLAudioPlayer *)sharedAudioPlayer
{
    static TLAudioPlayer *audioPlayer;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        audioPlayer = [[TLAudioPlayer alloc] init];
        [audioPlayer configureAVAudioSession];
    });
    return audioPlayer;
}

- (void)playAudioAtPath:(NSString *)path complete:(void (^)(BOOL finished))complete;
{
    if (self.player && self.player.isPlaying) {
        [self stopPlayingAudio];
    }
    self.completeBlock = complete;
    NSError *error;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&error];
    [self.player setDelegate:self];
    if (error) {
        if (complete) {
            complete(NO);
        }
        return;
    }
    [self.player play];
}

- (void)configureAVAudioSession
{
    // Get your app's audioSession singleton object
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // Error handling
    BOOL success;
    NSError *error;
    
    // set the audioSession category.
    // Needs to be Record or PlayAndRecord to use audioRouteOverride:
    
    success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                             error:&error];
    
    if (!success) {
        NSLog(@"AVAudioSession error setting category:%@",error);
    }
    
    // Set the audioSession override
    success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                         error:&error];
    if (!success) {
        NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
    }
    
    // Activate the audio session
    success = [session setActive:YES error:&error];
    if (!success) {
        NSLog(@"AVAudioSession error activating: %@",error);
    }
    else {
        NSLog(@"AudioSession active");
    }
    
}

- (void)stopPlayingAudio
{
    [self.player stop];
    if (self.completeBlock) {
        self.completeBlock(NO);
    }
}

- (BOOL)isPlaying
{
    if (self.player) {
        return self.player.isPlaying;
    }
    return NO;
}

#pragma mark - # Delegate
//MARK: AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (self.completeBlock) {
        self.completeBlock(YES);
        self.completeBlock = nil;
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    DDLogError(@"音频播放出现错误：%@", error);
    if (self.completeBlock) {
        self.completeBlock(NO);
        self.completeBlock = nil;
    }
}

@end
