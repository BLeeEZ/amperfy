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
    
    private func resync(libraryStorage: LibraryStorage, syncWave: SyncWaveMO) {
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
            let artistsLeft = allArtists.filter {
                return $0.id > syncWave.syncIndexToContinue
            }
            let artistsSorted = artistsLeft.sorted{
                return $0.id < $1.id
            }
            os_log("Lib resync: Albums parsing start", log: log, type: .info)
            for artist in artistsSorted {
                let albumDelegate = SsAlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
                subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artist.id)
                syncWave.syncIndexToContinue = Int(artist.id)
                if(!isRunning) { break }
            }

            if artistsSorted.isEmpty || syncWave.syncIndexToContinue == artistsSorted.last?.id ?? 0 {
                os_log("Lib resync: Albums parsing done", log: log, type: .info)
                syncWave.syncState = .Songs
            }
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Songs, isRunning {
            let allAlbums = libraryStorage.getAlbums()
            let albumsLeft = allAlbums.filter {
                return $0.id > syncWave.syncIndexToContinue
            }
            let albumsSorted = albumsLeft.sorted{
                return $0.id < $1.id
            }
            os_log("Lib resync: Songs parsing start", log: log, type: .info)
            for album in albumsSorted {
                let songDelegate = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
                subsonicServerApi.requestAlbum(parserDelegate: songDelegate, id: album.id)
                syncWave.syncIndexToContinue = Int(album.id)
                if(!isRunning) { break }
            }

            if albumsSorted.isEmpty || syncWave.syncIndexToContinue == albumsSorted.last?.id ?? 0 {
                os_log("Lib resync: Songs parsing done", log: log, type: .info)
                syncWave.syncState = .Done
            }
            libraryStorage.saveContext()
        }
    }
    
}
