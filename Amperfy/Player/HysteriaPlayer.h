//
//  HysteriaPlayer.h
//
//  Version 1.0
//
//  Created by Saiday on 01/14/2013.
//  Copyright 2013 StreetVoice
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <AvailabilityMacros.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HysteriaPlayerReadyToPlay) {
    HysteriaPlayerReadyToPlayPlayer = 3000,
    HysteriaPlayerReadyToPlayCurrentItem = 3001,
};

typedef NS_ENUM(NSInteger, HysteriaPlayerFailed) {
    HysteriaPlayerFailedPlayer = 4000,
    HysteriaPlayerFailedCurrentItem = 4001,
};

@class HysteriaPlayer;

/**
 *  HysteriaPlayerDelegate, all delegate method is optional.
 */
@protocol HysteriaPlayerDelegate <NSObject>

- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer willChangePlayerItemAtIndex:(NSInteger)index;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didChangeCurrentItem:(AVPlayerItem *)item;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didEvictCurrentItem:(AVPlayerItem *)item;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer rateDidChange:(float)rate;
- (void)hysteriaPlayerDidReachEnd:(HysteriaPlayer *)hysteriaPlayer;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didPreloadCurrentItemWithTime:(CMTime)time;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didFailWithIdentifier:(HysteriaPlayerFailed)identifier error:(NSError *)error;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didReadyToPlayWithIdentifier:(HysteriaPlayerReadyToPlay)identifier;

- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didFailedWithPlayerItem:(AVPlayerItem * _Nullable)item toPlayToEndTimeWithError:(NSError *)error;
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer didStallWithPlayerItem:(AVPlayerItem * _Nullable)item;

@end

@protocol HysteriaPlayerDataSource <NSObject>

@optional

/**
 *  Asks the data source to return the number of items that HysteriaPlayer would play.
 *
 *  @return items count
 */
- (NSInteger)numberOfItemsInHysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer;

/**
 *  Source URL provider, hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer: is for async task usage.
 *
 *  @param index     index of the item
 *  @param preBuffer ask URL for pre buffer or not
 *
 *  @return source URL
 */
- (NSURL *)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer URLForItemAtIndex:(NSInteger)index preBuffer:(BOOL)preBuffer;

/**
 *  Source URL provider, would excute until you call setupPlayerItemWithUrl:index:
 *
 *  @param index     index of the item
 *  @param preBuffer ask URL for pre buffer or not
 */
- (void)hysteriaPlayer:(HysteriaPlayer *)hysteriaPlayer asyncSetUrlForItemAtIndex:(NSInteger)index preBuffer:(BOOL)preBuffer;

@end

typedef void (^ Failed)(HysteriaPlayerFailed identifier, NSError *error) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");
typedef void (^ ReadyToPlay)(HysteriaPlayerReadyToPlay identifier) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");
typedef void (^ SourceAsyncGetter)(NSInteger index) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");
typedef NSURL * _Nonnull (^ SourceSyncGetter)(NSInteger index) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");

typedef NS_ENUM(NSInteger, HysteriaPlayerStatus) {
    HysteriaPlayerStatusPlaying = 0,
    HysteriaPlayerStatusForcePause,
    HysteriaPlayerStatusBuffering,
    HysteriaPlayerStatusUnknown,
};

typedef NS_ENUM(NSInteger, HysteriaPlayerRepeatMode) {
    HysteriaPlayerRepeatModeOn = 0,
    HysteriaPlayerRepeatModeOnce,
    HysteriaPlayerRepeatModeOff,
};

typedef NS_ENUM(NSInteger, HysteriaPlayerShuffleMode) {
    HysteriaPlayerShuffleModeOn = 0,
    HysteriaPlayerShuffleModeOff,
};

@interface HysteriaPlayer : NSObject <AVAudioPlayerDelegate>

@property (nonatomic, strong, nullable) AVQueuePlayer *audioPlayer;
@property (nonatomic, weak, nullable) id<HysteriaPlayerDelegate> delegate;
@property (nonatomic, weak, nullable) id<HysteriaPlayerDataSource> datasource;
@property (nonatomic) NSInteger itemsCount;
@property (nonatomic) BOOL disableLogs;
@property (nonatomic, strong, readonly, nullable) NSArray *playerItems;
@property (nonatomic, readonly) BOOL emptySoundPlaying;
@property (nonatomic) BOOL skipEmptySoundPlaying;
@property (nonatomic) BOOL popAlertWhenError;

+ (HysteriaPlayer *)sharedInstance;

- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDelegate instead");
- (void)registerHandlerFailed:(Failed)failed DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDelegate instead");


- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSInteger) count DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDataSource instead.");
- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSInteger)count DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDataSource instead.");
- (void)setItemsCount:(NSInteger)count DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDataSource instead.");

/**
 *   This method is necessary if you implement hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer: delegate method,
     provide source URL to HysteriaPlayer.
     Should not use this method outside of hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer: scope.
 *
 *  @param url   source URL
 *  @param index index which hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer: sent you
 */
- (void)setupPlayerItemWithUrl:(NSURL *)url index:(NSInteger)index;
- (void)setupPlayerItemWithAVURLAsset:(AVURLAsset *)asset index:(NSInteger)index;
- (void)fetchAndPlayPlayerItem:(NSInteger)startAt;
- (void)removeAllItems;
- (void)removeQueuesAtPlayer;

/**
 *   Be sure you update hysteriaPlayerNumberOfItems or itemsCount when you remove items
 *
 *  @param index index to removed
 */
- (void)removeItemAtIndex:(NSInteger)index;
- (void)moveItemFromIndex:(NSInteger)from toIndex:(NSInteger)to;
- (void)play;
- (void)pause;
- (void)pausePlayerForcibly:(BOOL)forcibly DEPRECATED_MSG_ATTRIBUTE("use pause instead.");
- (void)playPrevious;
- (void)playNext;
- (void)seekToTime:(double)CMTime;
- (void)seekToTime:(double)CMTime withCompletionBlock:(void (^ _Nullable)(BOOL finished))completionBlock;

- (void)setPlayerRepeatMode:(HysteriaPlayerRepeatMode)mode NS_SWIFT_NAME(setRepeatMode(mode:));
- (HysteriaPlayerRepeatMode)getPlayerRepeatMode NS_SWIFT_NAME(repeatMode());
- (void)setPlayerShuffleMode:(HysteriaPlayerShuffleMode)mode NS_SWIFT_NAME(setShuffleMode(mode:));
- (HysteriaPlayerShuffleMode)getPlayerShuffleMode NS_SWIFT_NAME(shuffleMode());

- (BOOL)isPlaying;
- (NSInteger)getLastItemIndex NS_SWIFT_NAME(lastItemIndex());
- (AVPlayerItem * _Nullable)getCurrentItem NS_SWIFT_NAME(currentItem());
- (HysteriaPlayerStatus)getHysteriaPlayerStatus NS_SWIFT_NAME(status());

- (void)addDelegate:(id<HysteriaPlayerDelegate>)delegate DEPRECATED_MSG_ATTRIBUTE("set delegate property instead");
- (void)removeDelegate:(id<HysteriaPlayerDelegate>)delegate DEPRECATED_MSG_ATTRIBUTE("Use delegate property instead");;

- (float)getPlayingItemCurrentTime NS_SWIFT_NAME(playingItemCurrentTime());
- (float)getPlayingItemDurationTime NS_SWIFT_NAME(playingItemDurationTime());
- (id)addBoundaryTimeObserverForTimes:(NSArray *)times queue:(dispatch_queue_t _Nullable)queue usingBlock:(void (^)(void))block;
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval queue:(dispatch_queue_t _Nullable)queue usingBlock:(void (^)(CMTime time))block;
- (void)removeTimeObserver:(id)observer;

/**
 *  Default is true
 *
 *  @param isMemoryCached cache
 */
- (void)enableMemoryCached:(BOOL)memoryCache;
- (BOOL)isMemoryCached;

/**
 *  Indicating Playeritem's play index
 *
 *  @param item item
 *
 *  @return index of the item
 */
- (NSNumber * _Nullable)getHysteriaIndex:(AVPlayerItem *)item;

- (void)deprecatePlayer;

@end

NS_ASSUME_NONNULL_END
