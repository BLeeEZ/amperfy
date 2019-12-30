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
    let playlistEntry: PlaylistElement
    let reactionToError: FetchErrorReaction
}

class BackendAudioPlayer: SongDownloadNotifiable {

    private let downloadManager: DownloadManager
    private let player = AVPlayer()
    private let updateElapsedTimeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    private var latestPlayRequest: PlayRequest?
    private let semaphore = DispatchSemaphore(value: 1)
    
    public private(set) var isPlaying: Bool = false
    public private(set) var currentlyPlaying: PlaylistElement?
    
    var responder: BackendAudioPlayerNotifiable?
    var elapsedTime: Double {
        if !player.currentTime().seconds.isFinite {
            return 0.0
        }
        return player.currentTime().seconds
    }
    var duration: Double {
        guard let duration = player.currentItem?.asset.duration.seconds else {
            return 0.0
        }
        if !duration.isFinite {
            return 0.0
        }
        return duration
    }
    var canBeContinued: Bool {
        return player.currentItem != nil
    }
    
    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
        
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
    
    func updateCurrentlyPlayingReference(playlistEntry: PlaylistElement) {
        if currentlyPlaying?.song?.id == playlistEntry.song?.id {
            currentlyPlaying = playlistEntry
        }
    }
    
    func requestToPlay(playlistEntry: PlaylistElement, reactionToError: FetchErrorReaction) {
        semaphore.wait()
        latestPlayRequest = PlayRequest(playlistEntry: playlistEntry, reactionToError: reactionToError)
        guard let song = playlistEntry.song else { return }
        if song.isCached {
            insertCachedSong(playlistEntry: playlistEntry)
            self.continuePlay()
            self.reactToInsertationFinish(playlistEntry: playlistEntry)
        } else {
            downloadManager.download(song: song, notifier: self, priority: .high)
        }
        semaphore.signal()
    }
    
    private func insertCachedSong(playlistEntry: PlaylistElement) {
        guard let song = playlistEntry.song, let songData = song.fileData else { return }
        os_log(.default, "Play song: %s", song.displayString)
        let url = createLocalUrl(songData: songData)
        player.pause()
        player.replaceCurrentItem(with: nil)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        NotificationCenter.default.addObserver(self, selector: #selector(songFinishedPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

    private func reactToInsertationFinish(playlistEntry: PlaylistElement) {
        currentlyPlaying = playlistEntry
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
    
    private func createLocalUrl(songData: NSData) -> URL {
        let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tempDirectoryURL.appendingPathComponent("curSong.mp3")
        songData.write(to: url, atomically: true)
        return url
    }
    
    func finished(downloading song: Song, error: DownloadError?) {
        guard let playRequest = self.latestPlayRequest, song == playRequest.playlistEntry.song else { return }
        
        if let fetchError = error {
            if fetchError == .noConnectivity {
                self.reactToInsertationFinish(playlistEntry: playRequest.playlistEntry)
                switch playRequest.reactionToError {
                case .playPrevious:
                    self.reactToError(reaction: .playPreviousCached)
                case .playNext:
                    self.reactToError(reaction: .playNextCached)
                default:
                    self.reactToError(reaction: .stop)
                }
                
            } else {
                self.reactToInsertationFinish(playlistEntry: playRequest.playlistEntry)
                self.reactToError(reaction: playRequest.reactionToError)
            }
        } else {
            self.insertCachedSong(playlistEntry: playRequest.playlistEntry)
            self.continuePlay()
            self.reactToInsertationFinish(playlistEntry: playRequest.playlistEntry)
        }
    }
    
}
