import Foundation
import CoreData
import os.log

class SubsonicLibraryBackgroundSyncer: GenericLibraryBackgroundSyncer, BackgroundLibrarySyncer {
    
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }

    func syncInBackground(library: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true

        if let latestSyncWave = library.getLatestSyncWave(), !latestSyncWave.isDone {
            os_log("Lib resync: Continue last resync", log: log, type: .info)
            resync(library: library, syncWave: latestSyncWave)
        } else {
            os_log("Lib resync: Start resync again", log: log, type: .info)
            let syncWave = library.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
            library.saveContext()
            resync(library: library, syncWave: syncWave)
        } 
        
        isActive = false
        semaphoreGroup.leave()
    }   
    
    private func resync(library: LibraryStorage, syncWave: SyncWave) {
        if syncWave.syncState == .Artists, isRunning {
            os_log("Lib resync: Artist parsing start", log: log, type: .info)
            let artistParser = SsArtistParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
            subsonicServerApi.requestArtists(parserDelegate: artistParser)

            os_log("Lib resync: Artist parsing done", log: log, type: .info)
            syncWave.syncState = .Albums
            library.saveContext()
        }
        if syncWave.syncState == .Albums, isRunning {
            let allArtists = library.getArtists()
            let artistsLeftUnsorted = allArtists.filter {
                return $0.id.localizedStandardCompare(syncWave.syncIndexToContinue) == ComparisonResult.orderedDescending
            }
            let artistsLeftSorted = artistsLeftUnsorted.sorted {
                return $0.id.localizedStandardCompare($1.id) == ComparisonResult.orderedAscending
            }
            os_log("Lib resync: Albums parsing start", log: log, type: .info)
            for artist in artistsLeftSorted {
                let albumDelegate = SsAlbumParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
                albumDelegate.guessedArtist = artist
                subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artist.id)
                syncWave.syncIndexToContinue = artist.id
                if(!isRunning) { break }
            }

            if artistsLeftSorted.isEmpty || syncWave.syncIndexToContinue == artistsLeftSorted.last?.id ?? "" {
                os_log("Lib resync: Albums parsing done", log: log, type: .info)
                syncWave.syncState = .Done
            }
            library.saveContext()
        }
        if syncWave.syncState == .Songs, isRunning {
            syncWave.syncState = .Done
            library.saveContext()
        }
    }
    
}
