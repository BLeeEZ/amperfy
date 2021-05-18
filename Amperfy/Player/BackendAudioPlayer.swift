import Foundation
import AVFoundation
import os.log

enum FetchErrorReaction {
    case playPrevious
    case playPreviousCached
    case playNext
    case playNextCached
    case stop
}

protocol BackendAudioPlayerNotifiable {
    func didElapsedTimeChange()
    func stop()
    func playPrevious()
    func playPreviousCached()
    func playNext()
    func playNextCached()
    func didSongFinishedPlaying()
    func notifySongPreparationFinished()
}

struct PlayRequest {
    let playlistItem: PlaylistItem
    let reactionToError: FetchErrorReaction
}

class BackendAudioPlayer: SongDownloadNotifiable {

    private let songDownloader: SongDownloadable
    private let songCache: SongFileCachable
    private let player: AVPlayer
    private let eventLogger: EventLogger
    private let updateElapsedTimeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    private var latestPlayRequest: PlayRequest?
    private let semaphore = DispatchSemaphore(value: 1)
    
    public private(set) var isPlaying: Bool = false
    public private(set) var currentlyPlaying: PlaylistItem?
    
    var responder: BackendAudioPlayerNotifiable?
    var elapsedTime: Double {
        guard player.currentItem?.status == AVPlayerItem.Status.readyToPlay else {
            return 0.0
        }
        let elapsedTimeInSeconds = player.currentTime().seconds
        guard elapsedTimeInSeconds.isFinite else {
            return 0.0
        }
        return elapsedTimeInSeconds
    }
    var duration: Double {
        guard player.currentItem?.status == AVPlayerItem.Status.readyToPlay,
              let duration = player.currentItem?.asset.duration.seconds,
              duration.isFinite else {
            return 0.0
        }
        return duration
    }
    var canBeContinued: Bool {
        return player.currentItem != nil
    }
    
    init(mediaPlayer: AVPlayer, eventLogger: EventLogger, songDownloader: SongDownloadable, songCache: SongFileCachable) {
        self.player = mediaPlayer
        self.eventLogger = eventLogger
        self.songDownloader = songDownloader
        self.songCache = songCache
        
        player.addPeriodicTimeObserver(forInterval: updateElapsedTimeInterval, queue: DispatchQueue.main) { [weak self] time in
            if let self = self {
                self.responder?.didElapsedTimeChange()
            }
        }
    }
    
    @objc private func songFinishedPlaying() {
        responder?.didSongFinishedPlaying()
    }
    
    func continuePlay() {
        isPlaying = true
        player.play()
    }
    
    func pause() {
        isPlaying = false
        player.pause()
    }
    
    func stop() {
        isPlaying = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentlyPlaying = nil
    }
    
    func seek(toSecond: Double) {
        player.seek(to: CMTime(seconds: toSecond, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    func updateCurrentlyPlayingReference(playlistItem: PlaylistItem) {
        if currentlyPlaying?.song?.id == playlistItem.song?.id {
            currentlyPlaying = playlistItem
        }
    }
    
    func requestToPlay(playlistItem: PlaylistItem, reactionToError: FetchErrorReaction) {
        semaphore.wait()
        latestPlayRequest = PlayRequest(playlistItem: playlistItem, reactionToError: reactionToError)
        guard let song = playlistItem.song else { return }
        if !song.isPlayableOniOS, let contentType = song.contentType {
            player.pause()
            player.replaceCurrentItem(with: nil)
            eventLogger.info(message: "Content type \"\(contentType)\" of song \"\(song.displayString)\" is not playable via Amperfy.")
        } else {
            if song.isCached {
                insertCachedSong(playlistItem: playlistItem)
            } else {
                insertStreamSong(playlistItem: playlistItem)
                songDownloader.download(song: song, notifier: nil, priority: .high)
            }
        }
        self.continuePlay()
        self.reactToInsertationFinish(playlistItem: playlistItem)
        semaphore.signal()
    }
    
    private func insertCachedSong(playlistItem: PlaylistItem) {
        guard let song = playlistItem.song, let songData = songCache.getSongFile(forSong: song)?.data else { return }
        os_log(.default, "Play song: %s", song.displayString)
        let url = createLocalUrl(songData: songData)
        insertSong(forSong: song, withUrl: url)
    }
    
    private func insertStreamSong(playlistItem: PlaylistItem) {
        guard let song = playlistItem.song, let streamUrl = songDownloader.updateStreamingUrl(forSong: song) else { return }
        os_log(.default, "Streaming song: %s", song.displayString)
        insertSong(forSong: song, withUrl: streamUrl)
    }

    private func insertSong(forSong song: Song, withUrl url: URL) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        var item: AVPlayerItem?
        if let mimeType = song.iOsCompatibleContentType {
            let asset: AVURLAsset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey" : mimeType])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        player.replaceCurrentItem(with: item)
        NotificationCenter.default.addObserver(self, selector: #selector(songFinishedPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    private func reactToInsertationFinish(playlistItem: PlaylistItem) {
        currentlyPlaying = playlistItem
        self.responder?.notifySongPreparationFinished()
    }
    
    private func reactToError(reaction: FetchErrorReaction) {
        switch reaction {
        case .playPrevious:
            self.responder?.playPrevious()
        case .playPreviousCached:
            self.responder?.playPreviousCached()
        case .playNext:
            self.responder?.playNext()
        case .playNextCached:
            self.responder?.playNextCached()
        case .stop:
            self.responder?.stop()
        }
    }
    
    private func createLocalUrl(songData: Data) -> URL {
        let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tempDirectoryURL.appendingPathComponent("curSong.mp3")
        try! songData.write(to: url, options: Data.WritingOptions.atomic)
        return url
    }
    
    func finished(downloading song: Song, error: DownloadError?) {
        guard let playRequest = self.latestPlayRequest, song == playRequest.playlistItem.song else { return }
        
        if let fetchError = error {
            if fetchError == .noConnectivity {
                self.reactToInsertationFinish(playlistItem: playRequest.playlistItem)
                switch playRequest.reactionToError {
                case .playPrevious:
                    self.reactToError(reaction: .playPreviousCached)
                case .playNext:
                    self.reactToError(reaction: .playNextCached)
                default:
                    self.reactToError(reaction: .stop)
                }
            } else {
                self.reactToInsertationFinish(playlistItem: playRequest.playlistItem)
                self.reactToError(reaction: playRequest.reactionToError)
            }
        } else {
            self.insertCachedSong(playlistItem: playRequest.playlistItem)
            self.continuePlay()
            self.reactToInsertationFinish(playlistItem: playRequest.playlistItem)
        }
    }
    
}
