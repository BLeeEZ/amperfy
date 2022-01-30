import Foundation
import MediaPlayer

struct PlayContext {
    let index: Int
    let playables: [AbstractPlayable]
    
    init(index: Int = 0, playables: [AbstractPlayable]) {
        self.index = index
        self.playables = playables
    }

    func getActivePlayable() -> AbstractPlayable? {
        guard playables.count > 0, index < playables.count else { return nil }
        return playables[index]
    }
}

protocol PlayerFacade {
    var prevQueue: [AbstractPlayable] { get }
    var waitingQueue: [AbstractPlayable] { get }
    var nextQueue: [AbstractPlayable] { get }
    
    var isPlaying: Bool { get }
    func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable
    var currentlyPlaying: AbstractPlayable?  { get }
    var elapsedTime: Double { get }
    var duration: Double { get }
    var isShuffle: Bool { get }
    func toggleShuffle()
    var repeatMode: RepeatMode { get set }
    var isOfflineMode: Bool { get set }
    var isAutoCachePlayedItems: Bool { get set }

    func reinit(playerStatus: PlayerData, queueHandler: PlayQueueHandler)
    func seek(toSecond: Double)
    
    func insertFirstToNextInMainQueue(playables: [AbstractPlayable])
    func appendToNextInMainQueue(playables: [AbstractPlayable])
    func insertFirstToWaitingQueue(playables: [AbstractPlayable])
    func appendToWaitingQueue(playables: [AbstractPlayable])
    func removePlayable(at: PlayerIndex)
    func movePlayable(from: PlayerIndex, to: PlayerIndex)
    func clearWaitingQueue()
    func clearMainQueue()
    func clearQueues()

    func play()
    func play(context: PlayContext)
    func playShuffled(context: PlayContext)
    func play(playerIndex: PlayerIndex)
    func appendToNextInMainQueueAndPlay(playable: AbstractPlayable)
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
        return playerStatus.isShuffle
    }
    func toggleShuffle() {
        playerStatus.isShuffle = !isShuffle
        musicPlayer.notifyPlaylistUpdated()
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
    
    func insertFirstToNextInMainQueue(playables: [AbstractPlayable]) {
        queueHandler.addToPlaylistFirst(playables: playables)
    }
    
    func appendToNextInMainQueue(playables: [AbstractPlayable]) {
        queueHandler.appendToNextInMainQueue(playables: playables)
    }

    func insertFirstToWaitingQueue(playables: [AbstractPlayable]) {
        queueHandler.insertFirstToWaitingQueue(playables: playables)
    }
    
    func appendToWaitingQueue(playables: [AbstractPlayable]) {
        queueHandler.appendToWaitingQueue(playables: playables)
    }

    func removePlayable(at: PlayerIndex) {
        queueHandler.removePlayable(at: at)
    }
    
    func movePlayable(from: PlayerIndex, to: PlayerIndex) {
        queueHandler.movePlayable(from: from, to: to)
    }

    func clearWaitingQueue() {
        queueHandler.clearWaitingQueue()
    }
    
    func clearMainQueue() {
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
        clearMainQueue()
        queueHandler.clearWaitingQueue()
    }

    func play() {
        musicPlayer.play()
    }
    
    func play(context: PlayContext) {
        if playerStatus.isShuffle { playerStatus.isShuffle = false }
        musicPlayer.play(context: context)
    }
    
    func playShuffled(context: PlayContext) {
        guard !context.playables.isEmpty else { return }
        if playerStatus.isShuffle { playerStatus.isShuffle = false }
        let shuffleContext = PlayContext(index: Int.random(in: 0...context.playables.count-1), playables: context.playables)
        musicPlayer.play(context: shuffleContext)
        playerStatus.isShuffle = true
        musicPlayer.notifyPlaylistUpdated()
    }
    
    func play(playerIndex: PlayerIndex) {
        musicPlayer.play(playerIndex: playerIndex)
    }
    
    func appendToNextInMainQueueAndPlay(playable: AbstractPlayable) {
        queueHandler.appendToNextInMainQueue(playables: [playable])
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
