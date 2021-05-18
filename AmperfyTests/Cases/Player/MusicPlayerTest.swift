import XCTest
import AVFoundation
@testable import Amperfy

class MOCK_AVPlayerItem: AVPlayerItem {
    override var status: AVPlayerItem.Status {
        return AVPlayerItem.Status.readyToPlay
    }
}

class MOCK_AVPlayer: AVPlayer {
    var useMockCurrentItem = false
    
    override var currentItem: AVPlayerItem? {
        guard let curItem = super.currentItem else { return nil }
        if !useMockCurrentItem {
            return curItem
        } else {
            return MOCK_AVPlayerItem(asset: curItem.asset)
        }
    }
    
    override func currentTime() -> CMTime {
        let oldUseMock = useMockCurrentItem
        useMockCurrentItem = false
        let curTime = super.currentTime()
        useMockCurrentItem = oldUseMock
        return curTime
    }
}

class MOCK_SongDownloader: SongDownloadable {
    
    var downloadCount = 0
    var songArg = [Song]()
    var notifierArg = [SongDownloadNotifiable?]()
    var priorityArg = [Priority]()
    
    func download(song: Song, notifier: SongDownloadNotifiable?, priority: Priority) {
        downloadCount += 1
        songArg.append(song)
        notifierArg.append(notifier)
        priorityArg.append(priority)
    }
    
    func updateStreamingUrl(forSong song: Song) -> URL? {
        return nil
    }
    
    func isNoDownloadRequested() -> Bool {
        return downloadCount == 0
    }
    
}

class MOCK_AlertDisplayable: AlertDisplayable {
    func display(alert: UIAlertController) {}
}

class MusicPlayerTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var storage: LibraryStorage!
    var mockAlertDisplayer: MOCK_AlertDisplayable!
    var eventLogger: EventLogger!
    var songDownloader: MOCK_SongDownloader!
    var backendPlayer: BackendAudioPlayer!
    var playerData: PlayerData!
    var testPlayer: Amperfy.MusicPlayer!
    var mockAVPlayer: MOCK_AVPlayer!
    
    var songCached: Song!
    var songToDownload: Song!
    var playlistThreeCached: Playlist!

    override func setUp() {
        cdHelper = CoreDataHelper()
        storage = cdHelper.createSeededStorage()
        songDownloader = MOCK_SongDownloader()
        mockAVPlayer = MOCK_AVPlayer()
        mockAlertDisplayer = MOCK_AlertDisplayable()
        eventLogger = EventLogger(alertDisplayer: mockAlertDisplayer, persistentContainer: cdHelper.persistentContainer)
        backendPlayer = BackendAudioPlayer(mediaPlayer: mockAVPlayer, eventLogger: eventLogger, songDownloader: songDownloader, songCache: storage)
        playerData = storage.getPlayerData()
        testPlayer = MusicPlayer(coreData: playerData, downloadManager: songDownloader, backendAudioPlayer: backendPlayer)
        
        guard let songCachedFetched = storage.getSong(id: "36") else { XCTFail(); return }
        songCached = songCachedFetched
        guard let songToDownloadFetched = storage.getSong(id: "3") else { XCTFail(); return }
        songToDownload = songToDownloadFetched
        guard let playlistCached = storage.getPlaylist(id: cdHelper.seeder.playlists[1].id) else { XCTFail(); return }
        playlistThreeCached = playlistCached
    }

    override func tearDown() {
    }
    
    func prepareWithCachedPlaylist() {
        for song in playlistThreeCached.songs {
            testPlayer.addToPlaylist(song: song)
        }
    }
    
    func markAsCached(song: Song) {
        let songFile = storage.createSongFile()
        songFile.info = song
        songFile.data = Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)
    }
    
    func testCreation() {
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertFalse(testPlayer.isShuffle)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
        XCTAssertEqual(testPlayer.playlist, playerData.playlist)
        XCTAssertEqual(testPlayer.elapsedTime, 0.0)
        XCTAssertEqual(testPlayer.duration, 0.0)
        XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
        XCTAssertTrue(songDownloader.isNoDownloadRequested())
    }
    
    func testPlay_EmptyPlaylist() {
        testPlayer.play()
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }
    
    func testPlay_OneCachedSongInPlayer_IsPlayingTrue() {
        testPlayer.addToPlaylist(song: songCached)
        testPlayer.play()
        XCTAssertTrue(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.song, songCached)
    }
    
    func testPlay_OneCachedSongInPlayer_NoDownloadRequest() {
        testPlayer.addToPlaylist(song: songCached)
        testPlayer.play()
        XCTAssertTrue(songDownloader.isNoDownloadRequested())
    }
    
    func testPlay_OneSongToDownload_IsPlayingTrue_AfterSuccessfulDownload() {
        testPlayer.addToPlaylist(song: songToDownload)
        testPlayer.play()
        XCTAssertTrue(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.song, songToDownload)
    }
    
    func testPlay_OneSongToDownload_CheckDownloadRequest() {
        testPlayer.addToPlaylist(song: songToDownload)
        testPlayer.play()
        XCTAssertEqual(songDownloader.downloadCount, 1)
        XCTAssertEqual(songDownloader.songArg.first, songToDownload)
    }
    
    func testPlaySong_Cached() {
        testPlayer.play(song: songCached)
        XCTAssertEqual(testPlayer.currentlyPlaying?.song, songCached)
    }
    
    func testPlaySong_CheckPlaylistClear() {
        prepareWithCachedPlaylist()
        testPlayer.play(song: songCached)
        XCTAssertEqual(testPlayer.playlist.songs.count, 1)
        XCTAssertEqual(testPlayer.currentlyPlaying?.song, songCached)
    }
    
    func testPlaySongInPlaylistAt_EmptyPlaylist() {
        testPlayer.play(songInPlaylistAt: 0)
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
        testPlayer.play(songInPlaylistAt: 5)
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
        testPlayer.play(songInPlaylistAt: -1)
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }
    
    func testPlaySongInPlaylistAt_Cached_FullPlaylist() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        XCTAssertTrue(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
    }
    
    func testPlaySongInPlaylistAt_FetchSuccess_FullPlaylist() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 2)
        XCTAssertTrue(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 2)
    }

    
    func testPause_EmptyPlaylist() {
        testPlayer.pause()
        XCTAssertFalse(testPlayer.isPlaying)
    }

    func testPause_CurrentlyPlaying() {
        testPlayer.addToPlaylist(song: songCached)
        testPlayer.play()
        testPlayer.pause()
        XCTAssertFalse(testPlayer.isPlaying)
    }
    
    func testPause_CurrentlyPaused() {
        testPlayer.addToPlaylist(song: songCached)
        testPlayer.pause()
        XCTAssertFalse(testPlayer.isPlaying)
    }
    
    func testPause_SongInMiddleOfPlaylist() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        XCTAssertTrue(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
        testPlayer.pause()
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
        testPlayer.play()
        XCTAssertTrue(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
    }
    
    func testAddToPlaylist() {
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
        testPlayer.addToPlaylist(song: songCached)
        XCTAssertEqual(testPlayer.playlist.songs.count, 1)
        testPlayer.addToPlaylist(song: songToDownload)
        XCTAssertEqual(testPlayer.playlist.songs.count, 2)
        testPlayer.addToPlaylist(song: songCached)
        XCTAssertEqual(testPlayer.playlist.songs.count, 3)
        testPlayer.addToPlaylist(song: songToDownload)
        XCTAssertEqual(testPlayer.playlist.songs.count, 4)
    }
  
    func testPlaylistClear_EmptyPlaylist() {
        testPlayer.cleanPlaylist()
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }
    
    func testPlaylistClear_FilledPlaylist() {
        prepareWithCachedPlaylist()
        testPlayer.cleanPlaylist()
        XCTAssertEqual(testPlayer.playlist.songs.count, 0)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }
    
    func testSeek_EmptyPlaylist() {
        testPlayer.seek(toSecond: 3.0)
        XCTAssertEqual(testPlayer.elapsedTime, 0.0)
    }
    
    func testSeek_FilledPlaylist() {
        testPlayer.play(song: songCached)
        testPlayer.seek(toSecond: 3.0)
        mockAVPlayer.useMockCurrentItem = true
        XCTAssertEqual(testPlayer.elapsedTime, 3.0)
        mockAVPlayer.useMockCurrentItem = false
    }
    
    func testPlayPreviousOrReplay_EmptyPlaylist() {
        testPlayer.playPreviousOrReplay()
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }
    
    func testPlayPreviousOrReplay_Previous() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.playPreviousOrReplay()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 2)
        XCTAssertEqual(testPlayer.elapsedTime, 0.0)
    }
    
    func testPlayPreviousOrReplay_Replay() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.seek(toSecond: 10.0)
        mockAVPlayer.useMockCurrentItem = true
        testPlayer.playPreviousOrReplay()
        mockAVPlayer.useMockCurrentItem = false
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
        XCTAssertEqual(testPlayer.elapsedTime, 0.0)
    }
    
    func testPlayPrevious_EmptyPlaylist() {
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }

    func testPlayPrevious_Normal() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 2)
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 1)
    }
    
    func testPlayPrevious_AtStart() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 0)
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayPrevious_RepeatAll() {
        prepareWithCachedPlaylist()
        testPlayer.repeatMode = .all
        testPlayer.play(songInPlaylistAt: 1)
        testPlayer.playPrevious()
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 8)
    }
    
    func testPlayPrevious_RepeatAll_OnlyOneSong() {
        testPlayer.play(song: songCached)
        testPlayer.repeatMode = .all
        testPlayer.playPrevious()
        testPlayer.playPrevious()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayPrevious_StartPlayIfPaused() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.pause()
        testPlayer.playPrevious()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayPrevious_IsPlayingStaysTrue() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.playPrevious()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayPreviousCached_EmptyPlaylist() {
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }

    func testPlayPreviousCached_Normal_FromCached() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayPreviousCached_Normal_FromDownload() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 8)
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 6)
    }
    
    func testPlayPreviousCached_AtStart() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 0)
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayPreviousCached_RepeatAll() {
        prepareWithCachedPlaylist()
        testPlayer.repeatMode = .all
        testPlayer.play(songInPlaylistAt: 1)
        testPlayer.playPreviousCached()
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 6)
    }
    
    func testPlayPreviousCached_RepeatAll_OnlyOneSong() {
        testPlayer.play(song: songCached)
        testPlayer.repeatMode = .all
        testPlayer.playPreviousCached()
        testPlayer.playPreviousCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayPreviousCached_StartPlayIfPaused() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.pause()
        testPlayer.playPreviousCached()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayPreviousCached_IsPlayingStaysTrue() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.playPreviousCached()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayNext_EmptyPlaylist() {
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }

    func testPlayNext_Normal() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 4)
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 5)
    }
    
    func testPlayNext_AtStart() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 0)
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 1)
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 2)
    }
    
    func testPlayNext_RepeatAll() {
        prepareWithCachedPlaylist()
        testPlayer.repeatMode = .all
        testPlayer.play(songInPlaylistAt: 8)
        testPlayer.playNext()
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 1)
    }
    
    func testPlayNext_RepeatAll_OnlyOneSong() {
        testPlayer.play(song: songCached)
        testPlayer.repeatMode = .all
        testPlayer.playNext()
        testPlayer.playNext()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayNext_StartPlayIfPaused() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.pause()
        testPlayer.playNext()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayNext_IsPlayingStaysTrue() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.playNext()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayNextCached_EmptyPlaylist() {
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }

    func testPlayNextCached_Normal_FromCached() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 3)
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 6)
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 8)
    }
    
    func testPlayNextCached_Normal_FromDownload() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 4)
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 6)
    }
    
    func testPlayNextCached_AtStart() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 8)
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 3)
    }
    
    func testPlayNextCached_RepeatAll() {
        prepareWithCachedPlaylist()
        testPlayer.repeatMode = .all
        testPlayer.play(songInPlaylistAt: 1)
        testPlayer.playNextCached()
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 6)
    }
    
    func testPlayNextCached_RepeatAll_OnlyOneSong() {
        testPlayer.play(song: songCached)
        testPlayer.repeatMode = .all
        testPlayer.playNextCached()
        testPlayer.playNextCached()
        XCTAssertEqual(testPlayer.currentlyPlaying?.index, 0)
    }
    
    func testPlayNextCached_StartPlayIfPaused() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.pause()
        testPlayer.playNextCached()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testPlayNextCached_IsPlayingStaysTrue() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.playNextCached()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testStop_EmptyPlaylist() {
        testPlayer.stop()
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    }
    
    func testStop_Playing() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.stop()
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 0)
    }
    
    func testStop_AlreadyStopped() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.stop()
        testPlayer.stop()
        XCTAssertFalse(testPlayer.isPlaying)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 0)
    }
    
    func testTogglePlay_EmptyPlaylist() {
        testPlayer.togglePlay()
        XCTAssertFalse(testPlayer.isPlaying)
        testPlayer.togglePlay()
        XCTAssertFalse(testPlayer.isPlaying)
        testPlayer.togglePlay()
        XCTAssertFalse(testPlayer.isPlaying)
    }
    
    func testTogglePlay_AfterPlay() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 6)
        testPlayer.togglePlay()
        XCTAssertFalse(testPlayer.isPlaying)
        testPlayer.togglePlay()
        XCTAssertTrue(testPlayer.isPlaying)
        testPlayer.togglePlay()
        XCTAssertFalse(testPlayer.isPlaying)
        testPlayer.togglePlay()
        XCTAssertTrue(testPlayer.isPlaying)
    }
    
    func testRemoveFromPlaylist_RemoveNotCurrentSong() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 4)
        testPlayer.removeFromPlaylist(at: 2)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 3)
        testPlayer.removeFromPlaylist(at: 6)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 3)
        testPlayer.removeFromPlaylist(at: 4)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 3)
        testPlayer.removeFromPlaylist(at: 0)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 2)
    }
    
    func testRemoveFromPlaylist_RemoveCurrentSong() {
        prepareWithCachedPlaylist()
        testPlayer.play(songInPlaylistAt: 4)
        let nextSong1 = testPlayer.playlist.songs[5]
        testPlayer.removeFromPlaylist(at: 4)
        XCTAssertEqual(testPlayer.currentlyPlaying?.song, nextSong1)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 4)
        
        testPlayer.play(songInPlaylistAt: 1)
        let nextSong2 = testPlayer.playlist.songs[2]
        testPlayer.removeFromPlaylist(at: 1)
        XCTAssertEqual(testPlayer.currentlyPlaying?.song, nextSong2)
        XCTAssertEqual(testPlayer.currentlyPlaying?.order, 1)
    }
    
}
