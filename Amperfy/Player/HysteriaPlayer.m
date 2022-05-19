//
//  HysteriaPlayer.m
//
//  Created by saiday on 13/1/8.
//
//

#import "HysteriaPlayer.h"
#import <objc/runtime.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioSession.h>
#endif

static const void *Hysteriatag = &Hysteriatag;
NSString *const kHysteriaPlayerErrorContext = @"Context";
NSErrorDomain const HysteriaPlayerErrorDomain = @"com.streetvoice.HysteriaPlayer.error";

typedef NS_ENUM(NSInteger, PauseReason) {
    PauseReasonNone,
    PauseReasonForced,
    PauseReasonBuffering,
};

@interface HysteriaPlayer ()
{
    BOOL routeChangedWhilePlaying;
    BOOL interruptedWhilePlaying;
    BOOL isPreBuffered;
    BOOL tookAudioFocus;
    
    NSInteger prepareingItemHash;
    
#if TARGET_OS_IPHONE
    UIBackgroundTaskIdentifier bgTaskId;
    UIBackgroundTaskIdentifier removedId;
#endif
    
    dispatch_queue_t HBGQueue;
}


@property (nonatomic, strong, readwrite) NSArray *playerItems;
@property (nonatomic, readwrite) BOOL emptySoundPlaying;
@property (nonatomic) NSInteger lastItemIndex;

@property (nonatomic) HysteriaPlayerRepeatMode repeatMode;
@property (nonatomic) HysteriaPlayerShuffleMode shuffleMode;
@property (nonatomic) HysteriaPlayerStatus hysteriaPlayerStatus;
@property (nonatomic) PauseReason pauseReason;
@property (nonatomic, strong) NSMutableSet *playedItems;

- (void)longTimeBufferBackground;
- (void)longTimeBufferBackgroundCompleted;

@end

@implementation HysteriaPlayer


static HysteriaPlayer *sharedInstance = nil;
static dispatch_once_t onceToken;

#pragma mark -
#pragma mark ===========  Initialization, Setup  =========
#pragma mark -

+ (HysteriaPlayer *)sharedInstance {
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

+ (void)showAlertWithError:(NSError *)error
{
#if TARGET_OS_IPHONE
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Player errors"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil, nil];
    [alert show];
#endif
}

- (id)init {
    self = [super init];
    if (self) {
        HBGQueue = dispatch_queue_create("com.hysteria.queue", NULL);
        _playerItems = [NSArray array];
        
        _repeatMode = HysteriaPlayerRepeatModeOff;
        _shuffleMode = HysteriaPlayerShuffleModeOff;
        _hysteriaPlayerStatus = HysteriaPlayerStatusUnknown;
    }
    
    return self;
}

- (void)preAction
{
    tookAudioFocus = YES;
    
    [self backgroundPlayable];
    [self playEmptySound];
    [self AVAudioSessionNotification];
}

- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay{}

- (void)registerHandlerFailed:(Failed)failed {}

- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSInteger)count {}

- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSInteger)count{}

- (void)setItemsCount:(NSInteger)count {}

- (void)playEmptySound
{
    if (self.skipEmptySoundPlaying) {
        self.audioPlayer = [[AVQueuePlayer alloc] init];
    } else {
        //play .1 sec empty sound
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *filepath = [bundle pathForResource:@"point1sec" ofType:@"mp3"];
        if ([[NSFileManager defaultManager]fileExistsAtPath:filepath]) {
            self.emptySoundPlaying = YES;
            AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filepath]];
            self.audioPlayer = [AVQueuePlayer queuePlayerWithItems:[NSArray arrayWithObject:playerItem]];
        }
    }
    
    if ([self.audioPlayer respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
        self.audioPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
}

- (void)backgroundPlayable
{
#if TARGET_OS_IPHONE
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    if (audioSession.category != AVAudioSessionCategoryPlayback) {
        UIDevice *device = [UIDevice currentDevice];
        if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
            if (device.multitaskingSupported) {
                
                NSError *aError = nil;
                [audioSession setCategory:AVAudioSessionCategoryPlayback error:&aError];
                if (aError) {
                    if (!self.disableLogs) {
                        NSLog(@"HysteriaPlayer: set category error:%@",[aError description]);
                    }
                }
                aError = nil;
                [audioSession setActive:YES error:&aError];
                if (aError) {
                    if (!self.disableLogs) {
                        NSLog(@"HysteriaPlayer: set active error:%@",[aError description]);
                    }
                }
            }
        }
    }else {
        if (!self.disableLogs) {
            NSLog(@"HysteriaPlayer: unable to register background playback");
        }
    }
    
    [self longTimeBufferBackground];
#endif
}


/*
 * Tells OS this application starts one or more long-running tasks, should end background task when completed.
 */
-(void)longTimeBufferBackground
{
#if TARGET_OS_IPHONE
    bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:removedId];
        bgTaskId = UIBackgroundTaskInvalid;
    }];
    
    if (bgTaskId != UIBackgroundTaskInvalid && removedId == 0 ? YES : (removedId != UIBackgroundTaskInvalid)) {
        [[UIApplication sharedApplication] endBackgroundTask: removedId];
    }
    removedId = bgTaskId;
#endif
}

-(void)longTimeBufferBackgroundCompleted
{
#if TARGET_OS_IPHONE
    if (bgTaskId != UIBackgroundTaskInvalid && removedId != bgTaskId) {
        [[UIApplication sharedApplication] endBackgroundTask: bgTaskId];
        removedId = bgTaskId;
    }
#endif
}


#pragma mark -
#pragma mark ===========  Runtime AssociatedObject  =========
#pragma mark -

- (void)setHysteriaIndex:(AVPlayerItem *)item key:(NSNumber *)order {
    objc_setAssociatedObject(item, Hysteriatag, order, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)getHysteriaIndex:(AVPlayerItem *)item {
    return objc_getAssociatedObject(item, Hysteriatag);
}

#pragma mark -
#pragma mark ===========  AVAudioSession Notifications  =========
#pragma mark -

- (void)AVAudioSessionNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemFailedToPlayToEndTime:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemPlaybackStall:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:nil];
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interruption:)
                                                 name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
#endif
    
    [self.audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer addObserver:self forKeyPath:@"rate" options:0 context:nil];
    [self.audioPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}

#pragma mark -
#pragma mark ===========  Player Methods  =========
#pragma mark -

- (void)willPlayPlayerItemAtIndex:(NSInteger)index
{
    if (!tookAudioFocus) {
        [self preAction];
    }
    self.lastItemIndex = index;
    [self.playedItems addObject:@(index)];
    
    if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:willChangePlayerItemAtIndex:)]) {
        [self.delegate hysteriaPlayer:self willChangePlayerItemAtIndex:self.lastItemIndex];
    }
}

- (void)fetchAndPlayPlayerItem:(NSInteger)startAt
{
    [self willPlayPlayerItemAtIndex:startAt];
    [self.audioPlayer pause];
    [self.audioPlayer removeAllItems];
    BOOL findInPlayerItems = NO;
    findInPlayerItems = [self findSourceInPlayerItems:startAt];
    if (!findInPlayerItems) {
        [self getSourceURLAtIndex:startAt preBuffer:NO];
    } else if (self.audioPlayer.currentItem.status == AVPlayerStatusReadyToPlay) {
        [self.audioPlayer play];
    }
}

- (NSInteger)hysteriaPlayerItemsCount
{
    if ([self.datasource respondsToSelector:@selector(numberOfItemsInHysteriaPlayer:)]) {
        return [self.datasource numberOfItemsInHysteriaPlayer:self];
    }
    return self.itemsCount;
}

- (void)getSourceURLAtIndex:(NSInteger)index preBuffer:(BOOL)preBuffer
{
    NSAssert([self.datasource respondsToSelector:@selector(hysteriaPlayer:URLForItemAtIndex:preBuffer:)] || [self.datasource respondsToSelector:@selector(hysteriaPlayer:asyncSetUrlForItemAtIndex:preBuffer:)], @"You didn't implement URL getter delegate from HysteriaPlayerDelegate, hysteriaPlayerURLForItemAtIndex:preBuffer: and hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer: provides for the use of alternatives.");
    NSAssert([self hysteriaPlayerItemsCount] > index, ([NSString stringWithFormat:@"You are about to access index: %li URL when your HysteriaPlayer items count value is %li, please check hysteriaPlayerNumberOfItems or set itemsCount directly.", (unsigned long)index, (unsigned long)[self hysteriaPlayerItemsCount]]));
    if ([self.datasource respondsToSelector:@selector(hysteriaPlayer:URLForItemAtIndex:preBuffer:)] && [self.datasource hysteriaPlayer:self URLForItemAtIndex:index preBuffer:preBuffer]) {
        dispatch_async(HBGQueue, ^{
            [self setupPlayerItemWithUrl:[self.datasource hysteriaPlayer:self URLForItemAtIndex:index preBuffer:preBuffer] index:index];
        });
    } else if ([self.datasource respondsToSelector:@selector(hysteriaPlayer:asyncSetUrlForItemAtIndex:preBuffer:)]) {
        [self.datasource hysteriaPlayer:self asyncSetUrlForItemAtIndex:index preBuffer:preBuffer];
    } else {
        NSLog(@"No HysteriaPlayer datasource detected at %li index", (unsigned long) index);
    }
}

- (void)setupPlayerItemWithUrl:(NSURL *)url index:(NSInteger)index
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    if (!item)
        return;
    [self setupPlayerItemWithAVPlayerItem:item index:index];
}

- (void)setupPlayerItemWithAVURLAsset:(AVURLAsset *)asset index:(NSInteger)index
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    if (!item)
        return;
    [self setupPlayerItemWithAVPlayerItem:item index:index];
}

- (void)setupPlayerItemWithAVPlayerItem:(AVPlayerItem *)playerItem index:(NSInteger)index
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setHysteriaIndex:playerItem key:[NSNumber numberWithInteger:index]];
        if (self.isMemoryCached) {
            NSMutableArray *playerItems = [NSMutableArray arrayWithArray:self.playerItems];
            [playerItems addObject:playerItem];
            self.playerItems = playerItems;
        }
        [self insertPlayerItem:playerItem];
    });
}


- (BOOL)findSourceInPlayerItems:(NSInteger)index
{
    for (AVPlayerItem *item in self.playerItems) {
        NSInteger checkIndex = [[self getHysteriaIndex:item] integerValue];
        if (checkIndex == index) {
            if (item.status == AVPlayerItemStatusReadyToPlay) {
                [item seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                    [self insertPlayerItem:item];
                }];
                return YES;
            }
        }
    }
    return NO;
}

- (void)prepareNextPlayerItem
{
    if (_shuffleMode == HysteriaPlayerShuffleModeOn || _repeatMode == HysteriaPlayerRepeatModeOnce) {
        return;
    }
    
    NSInteger nowIndex = self.lastItemIndex;
    BOOL findInPlayerItems = NO;
    NSInteger itemsCount = [self hysteriaPlayerItemsCount];
    
    if (nowIndex + 1 < itemsCount) {
        findInPlayerItems = [self findSourceInPlayerItems:nowIndex + 1];
        
        if (!findInPlayerItems) {
            [self getSourceURLAtIndex:nowIndex + 1 preBuffer:YES];
        }
    }
}

- (void)insertPlayerItem:(AVPlayerItem *)item
{
    if ([self.audioPlayer.items count] > 1) {
        for (int i = 1 ; i < [self.audioPlayer.items count] ; i ++) {
            [self.audioPlayer removeItem:[self.audioPlayer.items objectAtIndex:i]];
        }
    }
    if ([self.audioPlayer canInsertItem:item afterItem:nil]) {
        [self.audioPlayer insertItem:item afterItem:nil];
    }
}

- (void)removeAllItems
{
    for (AVPlayerItem *obj in self.audioPlayer.items) {
        [obj seekToTime:kCMTimeZero];
        @try {
            [obj removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
            [obj removeObserver:self forKeyPath:@"status" context:nil];
        } @catch(id anException) {
            //do nothing, obviously it wasn't attached because an exception was thrown
        }
    }
    
    self.playerItems = [self isMemoryCached] ? [NSArray array] : nil;
    [self.audioPlayer removeAllItems];
}

- (void)removeQueuesAtPlayer
{
    while (self.audioPlayer.items.count > 1) {
        [self.audioPlayer removeItem:[self.audioPlayer.items objectAtIndex:1]];
    }
}

- (void)removeItemAtIndex:(NSInteger)index
{
    if ([self isMemoryCached]) {
        for (AVPlayerItem *item in [NSArray arrayWithArray:self.playerItems]) {
            NSInteger checkIndex = [[self getHysteriaIndex:item] integerValue];
            if (checkIndex == index) {
                NSMutableArray *playerItems = [NSMutableArray arrayWithArray:self.playerItems];
                [playerItems removeObject:item];
                self.playerItems = playerItems;
                
                if ([self.audioPlayer.items indexOfObject:item] != NSNotFound) {
                    [self.audioPlayer removeItem:item];
                }
            } else if (checkIndex > index) {
                [self setHysteriaIndex:item key:[NSNumber numberWithInteger:checkIndex -1]];
            }
        }
    } else {
        for (AVPlayerItem *item in self.audioPlayer.items) {
            NSInteger checkIndex = [[self getHysteriaIndex:item] integerValue];
            if (checkIndex == index) {
                [self.audioPlayer removeItem:item];
            } else if (checkIndex > index) {
                [self setHysteriaIndex:item key:[NSNumber numberWithInteger:checkIndex -1]];
            }
        }
    }
}

- (void)moveItemFromIndex:(NSInteger)from toIndex:(NSInteger)to
{
    for (AVPlayerItem *item in self.playerItems) {
        [self resetItemIndexIfNeeds:item fromIndex:from toIndex:to];
    }
    
    for (AVPlayerItem *item in self.audioPlayer.items) {
        if ([self resetItemIndexIfNeeds:item fromIndex:from toIndex:to]) {
            [self removeQueuesAtPlayer];
        }
    }
}

- (BOOL)resetItemIndexIfNeeds:(AVPlayerItem *)item fromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex
{
    NSInteger checkIndex = [[self getHysteriaIndex:item] integerValue];
    BOOL found = NO;
    NSNumber *replaceOrder;
    if (checkIndex == sourceIndex) {
        replaceOrder = [NSNumber numberWithInteger:destinationIndex];
        found = YES;
    } else if (checkIndex == destinationIndex) {
        replaceOrder = sourceIndex > checkIndex ? @(checkIndex + 1) : @(checkIndex - 1);
        found = YES;
    } else if (checkIndex > destinationIndex && checkIndex < sourceIndex) {
        replaceOrder = [NSNumber numberWithInteger:(checkIndex + 1)];
        found = YES;
    } else if (checkIndex < destinationIndex && checkIndex > sourceIndex) {
        replaceOrder = [NSNumber numberWithInteger:(checkIndex - 1)];
        found = YES;
    }
    
    if (replaceOrder) {
        [self setHysteriaIndex:item key:replaceOrder];
        if (self.lastItemIndex == checkIndex) {
            self.lastItemIndex = [replaceOrder integerValue];
        }
    }
    return found;
}

- (void)seekToTime:(double)seconds
{
    [self.audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
}

- (void)seekToTime:(double)seconds withCompletionBlock:(void (^ _Nullable)(BOOL))completionBlock
{
    [self.audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        if (completionBlock) {
            completionBlock(finished);
        }
    }];
}

- (NSInteger)getLastItemIndex
{
    return self.lastItemIndex;
}

- (AVPlayerItem *)getCurrentItem
{
    return [self.audioPlayer currentItem];
}

- (void)play
{
    _pauseReason = PauseReasonNone;
    [self.audioPlayer play];
}

- (void)pause
{
    _pauseReason = PauseReasonForced;
    [self.audioPlayer pause];
}

- (void)playNext
{
    if (_shuffleMode == HysteriaPlayerShuffleModeOn) {
        NSInteger nextIndex = [self randomIndex];
        if (nextIndex != NSNotFound) {
            [self fetchAndPlayPlayerItem:nextIndex];
        } else {
            _pauseReason = PauseReasonForced;
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd:)]) {
                [self.delegate hysteriaPlayerDidReachEnd:self];
            }
        }
    } else {
        NSNumber *nowIndexNumber = [self getHysteriaIndex:self.audioPlayer.currentItem];
        NSInteger nowIndex = nowIndexNumber ? [nowIndexNumber integerValue] : self.lastItemIndex;
        if (nowIndex + 1 < [self hysteriaPlayerItemsCount]) {
            if (self.audioPlayer.items.count > 1) {
                [self willPlayPlayerItemAtIndex:nowIndex + 1];
                [self.audioPlayer advanceToNextItem];
            } else {
                [self fetchAndPlayPlayerItem:(nowIndex + 1)];
            }
        } else {
            if (_repeatMode == HysteriaPlayerRepeatModeOff) {
                _pauseReason = PauseReasonForced;
                if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd:)]) {
                    [self.delegate hysteriaPlayerDidReachEnd:self];
                }
            } else {
                [self fetchAndPlayPlayerItem:0];
            }
        }
    }
}

- (void)playPrevious
{
    NSInteger nowIndex = [[self getHysteriaIndex:self.audioPlayer.currentItem] integerValue];
    if (nowIndex == 0) {
        if (_repeatMode == HysteriaPlayerRepeatModeOn) {
            [self fetchAndPlayPlayerItem:[self hysteriaPlayerItemsCount] - 1];
        } else {
            [self pause];
            [self.audioPlayer.currentItem seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                [self play];
            }];
        }
    } else {
        [self fetchAndPlayPlayerItem:(nowIndex - 1)];
    }
}

- (CMTime)playerItemDuration
{
    NSError *err = nil;
    if ([self.audioPlayer.currentItem.asset statusOfValueForKey:@"duration" error:&err] == AVKeyValueStatusLoaded) {
        AVPlayerItem *playerItem = [self.audioPlayer currentItem];
        NSArray *loadedRanges = playerItem.seekableTimeRanges;
        if (loadedRanges.count > 0)
        {
            CMTimeRange range = [[loadedRanges objectAtIndex:0] CMTimeRangeValue];
            //Float64 duration = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
            return (range.duration);
        }else {
            return (kCMTimeInvalid);
        }
    } else {
        return (kCMTimeInvalid);
    }
}

- (void)setPlayerRepeatMode:(HysteriaPlayerRepeatMode)mode
{
    _repeatMode = mode;
}

- (HysteriaPlayerRepeatMode)getPlayerRepeatMode
{
    return _repeatMode;
}

- (void)setPlayerShuffleMode:(HysteriaPlayerShuffleMode)mode
{
    switch (mode) {
        case HysteriaPlayerShuffleModeOff:
            _shuffleMode = HysteriaPlayerShuffleModeOff;
            [_playedItems removeAllObjects];
            _playedItems = nil;
            break;
        case HysteriaPlayerShuffleModeOn:
            _shuffleMode = HysteriaPlayerShuffleModeOn;
            _playedItems = [NSMutableSet set];
            if (self.audioPlayer.currentItem) {
                [self.playedItems addObject:[self getHysteriaIndex:self.audioPlayer.currentItem]];
            }
            break;
        default:
            break;
    }
}

- (HysteriaPlayerShuffleMode)getPlayerShuffleMode
{
    return _shuffleMode;
}

- (void)pausePlayerForcibly:(BOOL)forcibly {}

#pragma mark -
#pragma mark ===========  Player info  =========
#pragma mark -

- (BOOL)isPlaying
{
    return self.emptySoundPlaying ? NO : self.audioPlayer.rate != 0.f;
}

- (HysteriaPlayerStatus)getHysteriaPlayerStatus
{
    if ([self isPlaying]) {
        return HysteriaPlayerStatusPlaying;
    } else {
        switch (_pauseReason) {
            case PauseReasonForced:
                return HysteriaPlayerStatusForcePause;
            case PauseReasonBuffering:
                return HysteriaPlayerStatusBuffering;
            default:
                return HysteriaPlayerStatusUnknown;
        }
    }
}

- (float)getPlayingItemCurrentTime
{
    CMTime itemCurrentTime = [[self.audioPlayer currentItem] currentTime];
    float current = CMTimeGetSeconds(itemCurrentTime);
    if (CMTIME_IS_INVALID(itemCurrentTime) || !isfinite(current))
        return 0.0f;
    else
        return current;
}

- (float)getPlayingItemDurationTime
{
    CMTime itemDurationTime = [self playerItemDuration];
    float duration = CMTimeGetSeconds(itemDurationTime);
    if (CMTIME_IS_INVALID(itemDurationTime) || !isfinite(duration))
        return 0.0f;
    else
        return duration;
}

- (id)addBoundaryTimeObserverForTimes:(NSArray *)times queue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block
{
    id boundaryObserver = [self.audioPlayer addBoundaryTimeObserverForTimes:times queue:queue usingBlock:block];
    return boundaryObserver;
}

- (id)addPeriodicTimeObserverForInterval:(CMTime)interval
                                   queue:(dispatch_queue_t)queue
                              usingBlock:(void (^)(CMTime time))block
{
    id mTimeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:interval queue:queue usingBlock:block];
    return mTimeObserver;
}

- (void)removeTimeObserver:(id)observer
{
    [self.audioPlayer removeTimeObserver:observer];
}

#pragma mark -
#pragma mark ===========  Interruption, Route changed  =========
#pragma mark -

- (void)interruption:(NSNotification*)notification
{
#if TARGET_OS_IPHONE
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger interuptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (interuptionType == AVAudioSessionInterruptionTypeBegan && _pauseReason != PauseReasonForced) {
        interruptedWhilePlaying = YES;
        [self pause];
    } else if (interuptionType == AVAudioSessionInterruptionTypeEnded && interruptedWhilePlaying) {
        interruptedWhilePlaying = NO;
        [self play];
    }
    if (!self.disableLogs) {
        NSLog(@"HysteriaPlayer: HysteriaPlayer interruption: %@", interuptionType == AVAudioSessionInterruptionTypeBegan ? @"began" : @"end");
    }
#endif
}

- (void)routeChange:(NSNotification *)notification
{
#if TARGET_OS_IPHONE
    NSDictionary *routeChangeDict = notification.userInfo;
    NSInteger routeChangeType = [[routeChangeDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    if (routeChangeType == AVAudioSessionRouteChangeReasonOldDeviceUnavailable && _pauseReason != PauseReasonForced) {
        routeChangedWhilePlaying = YES;
        [self pause];
    } else if (routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable && routeChangedWhilePlaying) {
        routeChangedWhilePlaying = NO;
        [self play];
    }
    if (!self.disableLogs) {
        NSLog(@"HysteriaPlayer: HysteriaPlayer routeChanged: %@", routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable ? @"New Device Available" : @"Old Device Unavailable");
    }
#endif
}

#pragma mark -
#pragma mark ===========  KVO  =========
#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == self.audioPlayer && [keyPath isEqualToString:@"status"]) {
        if (self.audioPlayer.status == AVPlayerStatusReadyToPlay) {
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didReadyToPlayWithIdentifier:)]) {
                [self.delegate hysteriaPlayer:self didReadyToPlayWithIdentifier:HysteriaPlayerReadyToPlayPlayer];
            }
            if (![self isPlaying]) {
                [self.audioPlayer play];
            }
        } else if (self.audioPlayer.status == AVPlayerStatusFailed) {
            if (!self.disableLogs) {
                NSLog(@"HysteriaPlayer: %@", self.audioPlayer.error);
            }
            
            if (self.popAlertWhenError) {
                [HysteriaPlayer showAlertWithError:self.audioPlayer.error];
            }
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didFailWithIdentifier:error:)]) {
                NSError *error = self.audioPlayer.error ? self.audioPlayer.error : [self unknownError];
                [self.delegate hysteriaPlayer:self didFailWithIdentifier:HysteriaPlayerFailedPlayer error:error];
            }
        }
    }
    
    if (object == self.audioPlayer && [keyPath isEqualToString:@"rate"]) {
        if (!self.emptySoundPlaying) {
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:rateDidChange:)]) {
                [self.delegate hysteriaPlayer:self rateDidChange:self.audioPlayer.rate];
            }
        }
    }
    
    if (object == self.audioPlayer && [keyPath isEqualToString:@"currentItem"]) {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        AVPlayerItem *lastPlayerItem = [change objectForKey:NSKeyValueChangeOldKey];
        if (lastPlayerItem != (id)[NSNull null] && lastPlayerItem != nil) {
            @try {
                [lastPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
                [lastPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
            } @catch(id anException) {
                //do nothing, obviously it wasn't attached because an exception was thrown
            }
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didEvictCurrentItem:)]) {
                [self.delegate hysteriaPlayer:self didEvictCurrentItem:lastPlayerItem];
            }
        }
        if (newPlayerItem != (id)[NSNull null]) {
            [newPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [newPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didChangeCurrentItem:)]) {
                [self.delegate hysteriaPlayer:self didChangeCurrentItem:newPlayerItem];
            }
            self.emptySoundPlaying = NO;
        }
    }
    
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
        isPreBuffered = NO;
        if (self.audioPlayer.currentItem.status == AVPlayerItemStatusFailed) {
            if (self.popAlertWhenError) {
                [HysteriaPlayer showAlertWithError:self.audioPlayer.currentItem.error];
            }
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didFailWithIdentifier:error:)]) {
                NSError *error = self.audioPlayer.currentItem.error ? self.audioPlayer.currentItem.error : [self unknownError];
                [self.delegate hysteriaPlayer:self didFailWithIdentifier:HysteriaPlayerFailedCurrentItem error:error];
            }
        } else if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didReadyToPlayWithIdentifier:)]) {
                [self.delegate hysteriaPlayer:self didReadyToPlayWithIdentifier:HysteriaPlayerReadyToPlayCurrentItem];
            }
            if (![self isPlaying] && _pauseReason != PauseReasonForced) {
                [self.audioPlayer play];
            }
        }
    }
    
    if (self.audioPlayer.items.count > 1 && object == [self.audioPlayer.items objectAtIndex:1] && [keyPath isEqualToString:@"loadedTimeRanges"]) {
        isPreBuffered = YES;
    }
    
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"loadedTimeRanges"]) {
        if (self.audioPlayer.currentItem.hash != prepareingItemHash) {
            [self prepareNextPlayerItem];
            prepareingItemHash = self.audioPlayer.currentItem.hash;
        }
        
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didPreloadCurrentItemWithTime:)]) {
                [self.delegate hysteriaPlayer:self didPreloadCurrentItemWithTime:CMTimeAdd(timerange.start, timerange.duration)];
            }
            
            if (self.audioPlayer.rate == 0 && _pauseReason != PauseReasonForced) {
                _pauseReason = PauseReasonBuffering;
                [self longTimeBufferBackground];
                
                CMTime bufferdTime = CMTimeAdd(timerange.start, timerange.duration);
                CMTime milestone = CMTimeAdd(self.audioPlayer.currentTime, CMTimeMakeWithSeconds(5.0f, timerange.duration.timescale));
                
                if (CMTIME_COMPARE_INLINE(bufferdTime , >, milestone) && self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay && !interruptedWhilePlaying && !routeChangedWhilePlaying) {
                    if (![self isPlaying]) {
                        if (!self.disableLogs) {
                            NSLog(@"HysteriaPlayer: resume from buffering..");
                        }
                        [self play];
                        [self longTimeBufferBackgroundCompleted];
                    }
                }
            }
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    AVPlayerItem *item = [notification object];
    if (![item isEqual:self.audioPlayer.currentItem]) {
        return;
    }
    
    NSNumber *currentItemIndex = [self getHysteriaIndex:self.audioPlayer.currentItem];
    if (currentItemIndex) {
        if (_repeatMode == HysteriaPlayerRepeatModeOnce) {
            NSInteger currentIndex = [currentItemIndex integerValue];
            [self fetchAndPlayPlayerItem:currentIndex];
        } else if (_shuffleMode == HysteriaPlayerShuffleModeOn) {
            NSInteger nextIndex = [self randomIndex];
            if (nextIndex != NSNotFound) {
                [self fetchAndPlayPlayerItem:[self randomIndex]];
            } else {
                [self pause];
                if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd:)]) {
                    [self.delegate hysteriaPlayerDidReachEnd:self];
                }
            }
        } else {
            if (self.audioPlayer.items.count == 1 || !isPreBuffered) {
                NSInteger nowIndex = [currentItemIndex integerValue];
                if (nowIndex + 1 < [self hysteriaPlayerItemsCount]) {
                    [self playNext];
                } else {
                    if (_repeatMode == HysteriaPlayerRepeatModeOff) {
                        [self pause];
                        if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd:)]) {
                            [self.delegate hysteriaPlayerDidReachEnd:self];
                        }
                    }else {
                        [self fetchAndPlayPlayerItem:0];
                    }
                }
            }
        }
    }
}

- (void)playerItemFailedToPlayToEndTime:(NSNotification *)notification {
    AVPlayerItem *item = [notification object];
    if (![item isEqual:self.audioPlayer.currentItem]) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didFailedWithPlayerItem:toPlayToEndTimeWithError:)]) {
        NSError *itemFailedToPlayToEndTimeError = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
        NSError *error = itemFailedToPlayToEndTimeError ? itemFailedToPlayToEndTimeError : [self unknownError];
        [self.delegate hysteriaPlayer:self didFailedWithPlayerItem:item toPlayToEndTimeWithError:error];
    }
}

- (void)playerItemPlaybackStall:(NSNotification *)notification {
    AVPlayerItem *item = [notification object];
    if (![item isEqual:self.audioPlayer.currentItem]) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(hysteriaPlayer:didStallWithPlayerItem:)]) {
        [self.delegate hysteriaPlayer:self didStallWithPlayerItem:item];
    }
}

- (NSInteger)randomIndex
{
    NSInteger itemsCount = [self hysteriaPlayerItemsCount];
    if ([self.playedItems count] == itemsCount) {
        self.playedItems = [NSMutableSet set];
        if (_repeatMode == HysteriaPlayerRepeatModeOff) {
            return NSNotFound;
        }
    }
    
    NSInteger index;
    do {
        index = arc4random() % itemsCount;
    } while ([_playedItems containsObject:[NSNumber numberWithInteger:index]]);
    
    return index;
}

- (NSError *)unknownError
{
    return [[NSError alloc] initWithDomain:HysteriaPlayerErrorDomain code:0 userInfo:@{kHysteriaPlayerErrorContext : @"unknown error"}];
}

#pragma mark -
#pragma mark ===========   Deprecation  =========
#pragma mark -

- (void)deprecatePlayer
{
    tookAudioFocus = NO;
#if TARGET_OS_IPHONE
    NSError *error;
    [[AVAudioSession sharedInstance] setActive:NO error:&error];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    if (error) {
        if (!self.disableLogs) {
            NSLog(@"HysteriaPlayer: set category error:%@", [error localizedDescription]);
        }
    }
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.audioPlayer removeObserver:self forKeyPath:@"status" context:nil];
    [self.audioPlayer removeObserver:self forKeyPath:@"rate" context:nil];
    [self.audioPlayer removeObserver:self forKeyPath:@"currentItem" context:nil];
    
    [self removeAllItems];
    
    [self.audioPlayer pause];
    self.delegate = nil;
    self.datasource = nil;
    self.audioPlayer = nil;
    
    onceToken = 0;
}

#pragma mark -
#pragma mark ===========   Memory cached  =========
#pragma mark -

- (BOOL)isMemoryCached
{
    return self.playerItems != nil;
}

- (void)enableMemoryCached:(BOOL)memoryCache
{
    if (self.playerItems == nil && memoryCache) {
        self.playerItems = [NSArray array];
    } else if (self.playerItems != nil && !memoryCache) {
        self.playerItems = nil;
    }
}

#pragma mark -
#pragma mark ===========   Delegation  =========
#pragma mark -

- (void)addDelegate:(id<HysteriaPlayerDelegate>)delegate{}

- (void)removeDelegate:(id<HysteriaPlayerDelegate>)delegate{}

@end
