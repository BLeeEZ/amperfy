import Foundation
import MediaPlayer

protocol PlayerFacade {
    var prevQueue: [AbstractPlayable] { get }
    var waitingQueue: [AbstractPlayable] { get }
    var nextQueue: [AbstractPlayable] { get }
    
    var isPlaying: Bool { get }
    func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable
    var currentlyPlaying: AbstractPlayable?  { get }
    var elapsedTime: Double { get }
    var duration: Double { get }
    var isShuffle: Bool { get set }
    var repeatMode: RepeatMode { get set }
    var isOfflineMode: Bool { get set }
    var isAutoCachePlayedItems: Bool { get set }

    func reinit(playerStatus: PlayerData, queueHandler: PlayQueueHandler)
    func seek(toSecond: Double)
    
    func addToPlaylist(playable: AbstractPlayable)
    func addToPlaylist(playables: [AbstractPlayable])
    func addToWaitingQueue(playable: AbstractPlayable)
    func removePlayable(at: PlayerIndex)
    func movePlayable(from: PlayerIndex, to: PlayerIndex)
    func insertAsNextSongNoPlay(playable: AbstractPlayable)
    func clearWaitingQueue()
    func clearPlaylist()
    func clearQueues()

    func play()
    func play(playable: AbstractPlayable)
    func play(playables: [AbstractPlayable])
    func play(playerIndex: PlayerIndex)
    func appendToNextQueueAndPlay(playable: AbstractPlayable)
    func togglePlay()
    func stop()
    func playPreviousOrReplay()
    func playNext()
    
    func addNotifier(notifier: MusicPlayable)
}

class PlayerFacadeImpl: PlayerFacade {
    
    private var playerStatus: PlayerStatusPersistent
    private var queueHandler: PlayQueueHandler
    private let backendAudioPlayer: BackendAudioPlayer
    private let musicPlayer: MusicPlayer
    private let userStatistics: UserStatistics
    
    init(playerStatus: PlayerStatusPersistent, queueHandler: PlayQueueHandler, musicPlayer: MusicPlayer, library: LibraryStorage, playableDownloadManager: DownloadManageable, backendAudioPlayer: BackendAudioPlayer, userStatistics: UserStatistics) {
        self.playerStatus = playerStatus
        self.queueHandler = queueHandler
        self.backendAudioPlayer = backendAudioPlayer
        self.musicPlayer = musicPlayer
        self.userStatistics = userStatistics
    }
    
    var prevQueue: [AbstractPlayable] {
        return queueHandler.prevQueue
    }
    var waitingQueue: [AbstractPlayable] {
        return queueHandler.waitingQueue
    }
    var nextQueue: [AbstractPlayable] {
        return queueHandler.nextQueue
    }
    
    var isPlaying: Bool {
        return backendAudioPlayer.isPlaying
    }
    func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable {
        return queueHandler.getPlayable(at: playerIndex)
    }
    var currentlyPlaying: AbstractPlayable? {
        return musicPlayer.currentlyPlaying
    }
    var elapsedTime: Double {
        return backendAudioPlayer.elapsedTime
    }
    var duration: Double {
        return backendAudioPlayer.duration
    }
    var isShuffle: Bool {
        get { return playerStatus.isShuffle }
        set {
            playerStatus.isShuffle = newValue
            musicPlayer.notifyPlaylistUpdated()
        }
    }
    var repeatMode: RepeatMode {
        get { return playerStatus.repeatMode }
        set { playerStatus.repeatMode = newValue }
    }
    var isOfflineMode: Bool {
        get { return backendAudioPlayer.isOfflineMode }
        set { backendAudioPlayer.isOfflineMode = newValue }
    }
    var isAutoCachePlayedItems: Bool {
        get { return playerStatus.isAutoCachePlayedItems }
        set {
            playerStatus.isAutoCachePlayedItems = newValue
            backendAudioPlayer.isAutoCachePlayedItems = newValue
        }
    }
    
    func reinit(playerStatus: PlayerData, queueHandler: PlayQueueHandler) {
        self.playerStatus = playerStatus
        self.queueHandler = queueHandler
        musicPlayer.reinit(playerStatus: playerStatus, queueHandler: queueHandler)
    }
    
    func seek(toSecond: Double) {
        userStatistics.usedAction(.playerSeek)
        backendAudioPlayer.seek(toSecond: toSecond)
    }
    
    func addToPlaylist(playable: AbstractPlayable) {
        queueHandler.addToPlaylist(playable: playable)
    }
    
    func addToPlaylist(playables: [AbstractPlayable]) {
        queueHandler.addToPlaylist(playables: playables)
    }
    
    func addToWaitingQueue(playable: AbstractPlayable) {
        queueHandler.addToWaitingQueue(playable: playable)
    }

    func removePlayable(at: PlayerIndex) {
        queueHandler.removePlayable(at: at)
    }
    
    func movePlayable(from: PlayerIndex, to: PlayerIndex) {
        queueHandler.movePlayable(from: from, to: to)
    }
    
    func insertAsNextSongNoPlay(playable: AbstractPlayable) {
        queueHandler.addToPlaylist(playable: playable)
        queueHandler.movePlayable(
            from: PlayerIndex(queueType: .next, index: queueHandler.nextQueue.count-1),
            to: PlayerIndex(queueType: .next, index: 0)
        )
    }
    
    func clearWaitingQueue() {
        queueHandler.clearWaitingQueue()
    }
    
    func clearPlaylist() {
        if !queueHandler.isWaitingQueuePlaying {
            if queueHandler.waitingQueue.isEmpty {
                musicPlayer.stop()
            } else {
                play(playerIndex: PlayerIndex(queueType: .waitingQueue, index: 0))
            }
        }
        queueHandler.clearPlaylistQueues()
    }
    
    func clearQueues() {
        clearPlaylist()
        queueHandler.clearWaitingQueue()
    }

    func play() {
        musicPlayer.play()
    }
    
    func play(playable: AbstractPlayable) {
        musicPlayer.play(playable: playable)
    }
    
    func play(playables: [AbstractPlayable]) {
        musicPlayer.play(playables: playables)
    }
    
    func play(playerIndex: PlayerIndex) {
        musicPlayer.play(playerIndex: playerIndex)
    }
    
    func appendToNextQueueAndPlay(playable: AbstractPlayable) {
        queueHandler.addToPlaylist(playable: playable)
        musicPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: queueHandler.nextQueue.count-1))
    }
    
    func togglePlay() {
        musicPlayer.togglePlay()
    }
    
    func stop() {
        musicPlayer.stop()
    }
    
    func playPreviousOrReplay() {
        musicPlayer.playPreviousOrReplay()
    }
    
    func playNext() {
        musicPlayer.playNext()
    }
    
    func addNotifier(notifier: MusicPlayable) {
        musicPlayer.addNotifier(notifier: notifier)
    }
    
}
