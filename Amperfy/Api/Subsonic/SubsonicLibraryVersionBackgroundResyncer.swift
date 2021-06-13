import Foundation
import CoreData
import os.log

class SubsonicLibraryVersionBackgroundResyncer: GenericLibraryBackgroundSyncer, BackgroundLibraryVersionResyncer {
    
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }

    func resyncDueToNewLibraryVersionInBackground(library: LibraryStorage, libraryVersion: LibrarySyncVersion) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true

        if let latestSyncWave = library.getLatestSyncWave(), latestSyncWave.syncType == .versionResync, latestSyncWave.version == libraryVersion , !latestSyncWave.isDone {
            os_log("Lib version resync: Continue update library version %s -> %s", log: log, type: .info, latestSyncWave.version.description, LibrarySyncVersion.newestVersion.description)
            resync(library: library, syncWave: latestSyncWave)
        } else {
            os_log("Lib version resync: Start update library version %s -> %s", log: log, type: .info, libraryVersion.description, LibrarySyncVersion.newestVersion.description)
            let syncWave = library.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
            syncWave.version = libraryVersion
            syncWave.syncType = .versionResync
            library.saveContext()
            resync(library: library, syncWave: syncWave)
        } 
        
        isActive = false
        semaphoreGroup.leave()
    }   
    
    private func resync(library: LibraryStorage, syncWave: SyncWave) {
        if syncWave.syncState == .Artists, isRunning {
            os_log("Lib version resync: Artist parsing start", log: log, type: .info)
            let artistDelegate = SsArtistParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
            subsonicServerApi.requestArtists(parserDelegate: artistDelegate)

            os_log("Lib version resync: Artist parsing done", log: log, type: .info)
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
            os_log("Lib version resync: Albums parsing start", log: log, type: .info)
            for artist in artistsLeftSorted {
                let albumDelegate = SsAlbumParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
                albumDelegate.guessedArtist = artist
                subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artist.id)
                syncWave.syncIndexToContinue = artist.id
                if(!isRunning) { break }
            }

            if artistsLeftSorted.isEmpty || syncWave.syncIndexToContinue == artistsLeftSorted.last?.id ?? "" {
                os_log("Lib version resync: Albums parsing done", log: log, type: .info)
                syncWave.syncState = .Done
            }
            library.saveContext()
        }
    }
    
}
