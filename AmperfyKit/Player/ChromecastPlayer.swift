//
//  ChromecastPlayer.swift
//  Amperfy
//
//  Created by Tobias Eisenschenk on 10.12.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//
import GoogleCast
import os.log
import PromiseKit

public class ChromecastPlayer: NSObject,
                               GCKSessionManagerListener,
                               GCKRemoteMediaClientListener,
                               GCKRequestDelegate,
                               GCKMediaQueueDelegate {
    private var backendApi: BackendApi!
    private var backendAudioPlayer: BackendAudioPlayer!
    private var queueHandler: PlayQueueHandler!
    private var sessionManager: GCKSessionManager!
    private var mediaClient: GCKRemoteMediaClient!
    private var mediaQueueItemIds: [NSNumber]
    
    init(backendApi: BackendApi, backendAudioPlayer: BackendAudioPlayer, queueHandler: PlayQueueHandler) {
        self.mediaQueueItemIds = []
        super.init()
        self.backendApi = backendApi
        self.backendAudioPlayer = backendAudioPlayer
        self.backendAudioPlayer.onSeek = { [self] to in
            os_log("seek called")
            self.seekRemote(to: to)
        }
        self.queueHandler = queueHandler
        self.queueHandler.onQueueInsert = { [self] playables, beforeItemAt in
            self.insertIntoQueue(playables: playables, beforeItemAt: beforeItemAt)
        }
        let castContext = GCKCastContext.sharedInstance()
        sessionManager = castContext.sessionManager
        sessionManager.add(self)
    }
    
    func generateMediaQueueItem(forPlayable playable: AbstractPlayable) -> Promise<GCKMediaQueueItem> {
        return backendApi.generateUrl(forDownloadingPlayable: playable).then { songUrl -> Promise<GCKMediaQueueItem> in
            let album = playable.isSong ? playable.asSong?.album : nil
            let albumArtUrl = album?.artwork?.url
            /*GCKMediaMetadata configuration*/
            let metadata = GCKMediaMetadata()
            metadata.setString(playable.title, forKey: kGCKMetadataKeyTitle)
            metadata.setString(playable.creatorName, forKey: kGCKMetadataKeyArtist)
            metadata.setString(album!.name, forKey: kGCKMetadataKeyAlbumTitle)
            if albumArtUrl != nil {
                metadata.addImage(GCKImage(url: URL(string: albumArtUrl!)!,
                                           width: 480,
                                           height: 360))
            }
            let mediaInfoBuilder = GCKMediaInformationBuilder(
                contentURL: URL(string: songUrl.absoluteString)!
            )
            mediaInfoBuilder.streamType = GCKMediaStreamType.none
            mediaInfoBuilder.contentType = "audio/mpeg"
            mediaInfoBuilder.metadata = metadata
            let mediaInformation = mediaInfoBuilder.build()
            
            let mediaQueueItemBuilder = GCKMediaQueueItemBuilder()
            mediaQueueItemBuilder.mediaInformation = mediaInformation
            mediaQueueItemBuilder.preloadTime = 10.0
            // autoplay otherwise will stop on next
            mediaQueueItemBuilder.autoplay = true
            let mediaQueueItem = mediaQueueItemBuilder.build()
            return Promise.value(mediaQueueItem)
        }
    }
    
    func castQueue(playables: [AbstractPlayable], elapsed: Double = 0.0, autoPlay: Bool = true, startIndex: Int = 0, _ completion: @escaping () -> Void) {
        if let remoteMediaClient = sessionManager.currentCastSession?.remoteMediaClient {
            let myMediaItems = playables.enumerated().map { index, playable in
                generateMediaQueueItem(forPlayable: playable)
            }
            let _ = when(fulfilled: myMediaItems).done { mediaItems in
                // os_log("built \(mediaItems.count) media items")
                let queueDataBuilder = GCKMediaQueueDataBuilder(queueType: .generic)
                queueDataBuilder.items = mediaItems
                queueDataBuilder.repeatMode = remoteMediaClient.mediaStatus?.queueRepeatMode ?? .off
                queueDataBuilder.startIndex = UInt(startIndex)
                
                /*Configuring the media request*/
                let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
                mediaLoadRequestDataBuilder.queueData = queueDataBuilder.build()
                mediaLoadRequestDataBuilder.startTime = elapsed
                mediaLoadRequestDataBuilder.autoplay = autoPlay ? 1 : 0
                let request = remoteMediaClient.loadMedia(with: mediaLoadRequestDataBuilder.build())
                request.delegate = self
                self.fetchQueueItemIds()
                completion()
            }
        }
    }
    
//  Inserts a liste of Playables into the casting queue before a given index or appends otherwise
    func insertIntoQueue(playables: [AbstractPlayable], beforeItemAt: Int? = nil) {
        os_log("CP: onAppendQueue \(playables.count)")
        if !sessionManager.hasConnectedCastSession() {
            return
        }
        if let remoteMediaClient = sessionManager.currentCastSession?.remoteMediaClient {
            if remoteMediaClient.mediaQueue.itemCount == 0 {
                castQueue(playables: playables, autoPlay: backendAudioPlayer.isPlaying, {})
                return
            }
            let myMediaItems = playables.enumerated().map { index, playable in
                generateMediaQueueItem(forPlayable: playable)
            }
            let _ = when(fulfilled: myMediaItems).done { mediaItems in
                // os_log("built \(mediaItems.count) media items")
                /*Configuring the media request*/
                if beforeItemAt != nil {
                    func getBeforeItemId() -> GCKMediaQueueItemID {
                        let prevQueueCount = self.queueHandler.prevQueue.count
                        let shouldAppend = prevQueueCount + 1 > self.mediaQueueItemIds.count
                        if shouldAppend {
                            return kGCKMediaQueueInvalidItemID
                        } else {
                            return self.mediaQueueItemIds[prevQueueCount+1].uintValue
                        }
                    }
                    let request = remoteMediaClient.queueInsert(mediaItems, beforeItemWithID: getBeforeItemId())
                    request.delegate = self
                } else {
                    let request = remoteMediaClient.queueInsert(mediaItems, beforeItemWithID: kGCKMediaQueueInvalidItemID)
                    request.delegate = self
                }
                self.fetchQueueItemIds()
            }
        }
    }
    
    func playRemote() {
        if sessionManager.hasConnectedSession() {
            sessionManager.currentCastSession?.remoteMediaClient?.play()
        }
    }
    
    func pauseRemote() {
        if sessionManager.hasConnectedSession() {
            sessionManager.currentCastSession?.remoteMediaClient?.pause()
        }
    }
    
    func stopRemote() {
        if sessionManager.hasConnectedSession() {
            sessionManager.currentCastSession?.remoteMediaClient?.stop()
        }
    }
    
    func seekRemote(to: Double = 0.0) {
        if sessionManager.hasConnectedSession() {
            let options = GCKMediaSeekOptions()
            options.interval = to
            sessionManager.currentCastSession?.remoteMediaClient?.seek(with: options)
        }
    }
    
    func syncQueue() {
        let startIndex = queueHandler.prevQueue.count
        guard let curr = queueHandler.currentlyPlaying else {
            self.castQueue(playables: queueHandler.prevQueue + queueHandler.nextQueue, startIndex: startIndex) {}
            return
        }
        let playQ = queueHandler.prevQueue + [curr] + queueHandler.nextQueue
        let elapsed = backendAudioPlayer.elapsedTime
        os_log("is backend playing \(self.backendAudioPlayer.isPlaying)")
        castQueue(playables: playQ, elapsed: elapsed, autoPlay: backendAudioPlayer.isPlaying, startIndex: startIndex) {}
    }
    
    func playNext() {
        if let remoteMediaClient = sessionManager.currentCastSession?.remoteMediaClient {
            let request = remoteMediaClient.queueNextItem()
            request.delegate = self
        }
    }
    
    func playPrevious() {
        if let remoteMediaClient = sessionManager.currentCastSession?.remoteMediaClient {
            let request = remoteMediaClient.queuePreviousItem()
            request.delegate = self
        }
    }
    
    func fetchQueueItemIds() {
        if let remoteMediaClient = sessionManager.currentCastSession?.remoteMediaClient {
            let ItemIdRequest = remoteMediaClient.queueFetchItemIDs()
            ItemIdRequest.delegate = self
        }
    }
    
    public func sessionManager(_: GCKSessionManager, didStart session: GCKSession) {
        os_log("The casting session started")
        self.backendAudioPlayer.mute()
        
        let currentTrack = self.queueHandler.currentlyPlaying
        if currentTrack == nil {
            return
        } else {
            syncQueue()
        }
        mediaClient = session.remoteMediaClient
        mediaClient.add(self)
    }
    
    public func sessionManager(_: GCKSessionManager, didResumeSession session: GCKSession) {
        os_log("Resumed casting session")
        self.backendAudioPlayer.mute()
        mediaClient = session.remoteMediaClient
        mediaClient.add(self)
    }
    
    public func sessionManager(_: GCKSessionManager, didEnd _: GCKSession, withError error: Error?) {
        os_log("The casting session ended")
        self.backendAudioPlayer.unmute()
        mediaClient.remove(self)
        mediaClient = nil
    }
    
    public func remoteMediaClientDidUpdateQueue(_: GCKRemoteMediaClient) {
        if let remoteMediaClient = self.sessionManager.currentCastSession?.remoteMediaClient {
            // os_log("updated cast Q length: \(remoteMediaClient.mediaQueue.itemCount)")
            fetchQueueItemIds()
        }
    }
    
    public func requestDidComplete(_ request: GCKRequest) {
        //mostly noise
        // os_log("request \(Int(request.requestID)) completed")
    }
    
    public func remoteMediaClient(_ client: GCKRemoteMediaClient, didReceiveQueueItemIDs queueItemIDs: [NSNumber]) {
        os_log("RemoteMediaClientListener: didReceiveQueueItemIDs \(queueItemIDs)")
        self.mediaQueueItemIds = queueItemIDs
    }

    public func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        os_log("request \(Int(request.requestID)) failed with error \(error)")
    }
}
