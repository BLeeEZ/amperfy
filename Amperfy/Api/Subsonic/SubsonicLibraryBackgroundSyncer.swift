import Foundation
import CoreData
import os.log

class SubsonicLibraryBackgroundSyncer: GenericLibraryBackgroundSyncer, BackgroundLibrarySyncer {
    
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }

    func syncInBackground(libraryStorage: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true

        if let latestSyncWave = libraryStorage.getLatestSyncWave(), !latestSyncWave.isDone {
            os_log("Lib resync: Continue last resync", log: log, type: .info)
            resync(libraryStorage: libraryStorage, syncWave: latestSyncWave)
        } else {
            os_log("Lib resync: Start resync again", log: log, type: .info)
            let syncWave = libraryStorage.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
            libraryStorage.saveContext()
            resync(libraryStorage: libraryStorage, syncWave: syncWave)
        } 
        
        isActive = false
        semaphoreGroup.leave()
    }   
    
    private func resync(libraryStorage: LibraryStorage, syncWave: SyncWave) {
        if syncWave.syncState == .Artists, isRunning {
            os_log("Lib resync: Artist parsing start", log: log, type: .info)
            let artistParser = SsArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
            subsonicServerApi.requestArtists(parserDelegate: artistParser)

            os_log("Lib resync: Artist parsing done", log: log, type: .info)
            syncWave.syncState = .Albums
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Albums, isRunning {
            let allArtists = libraryStorage.getArtists()
            let artistsLeftUnsorted = allArtists.filter {
                return $0.id.localizedStandardCompare(syncWave.syncIndexToContinue) == ComparisonResult.orderedDescending
            }
            let artistsLeftSorted = artistsLeftUnsorted.sorted {
                return $0.id.localizedStandardCompare($1.id) == ComparisonResult.orderedAscending
            }
            os_log("Lib resync: Albums parsing start", log: log, type: .info)
            for artist in artistsLeftSorted {
                let albumDelegate = SsAlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
                subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artist.id)
                syncWave.syncIndexToContinue = artist.id
                if(!isRunning) { break }
            }

            if artistsLeftSorted.isEmpty || syncWave.syncIndexToContinue == artistsLeftSorted.last?.id ?? "" {
                os_log("Lib resync: Albums parsing done", log: log, type: .info)
                syncWave.syncState = .Songs
            }
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Songs, isRunning {
            let allAlbums = libraryStorage.getAlbums()
            let albumsLeftUnsorted = allAlbums.filter {
                return $0.id.localizedStandardCompare(syncWave.syncIndexToContinue) == ComparisonResult.orderedDescending
            }
            let albumsLeftSorted = albumsLeftUnsorted.sorted{
                return $0.id.localizedStandardCompare($1.id) == ComparisonResult.orderedAscending
            }
            os_log("Lib resync: Songs parsing start", log: log, type: .info)
            for album in albumsLeftSorted {
                let songDelegate = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
                songDelegate.guessedArtist = album.artist
                songDelegate.guessedAlbum = album
                songDelegate.guessedGenre = album.genre
                subsonicServerApi.requestAlbum(parserDelegate: songDelegate, id: album.id)
                syncWave.syncIndexToContinue = album.id
                if(!isRunning) { break }
            }

            if albumsLeftSorted.isEmpty || syncWave.syncIndexToContinue == albumsLeftSorted.last?.id ?? "" {
                os_log("Lib resync: Songs parsing done", log: log, type: .info)
                syncWave.syncState = .Done
            }
            libraryStorage.saveContext()
        }
    }
    
}
