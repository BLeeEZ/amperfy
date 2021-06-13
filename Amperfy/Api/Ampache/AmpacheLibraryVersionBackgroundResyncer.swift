import Foundation
import CoreData
import os.log

class AmpacheLibraryVersionBackgroundResyncer: GenericLibraryBackgroundSyncer, BackgroundLibraryVersionResyncer {
   
    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
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
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let artistParser = ArtistParserDelegate(library: library, syncWave: syncWave)
                ampacheXmlServerApi.requestArtists(parserDelegate: artistParser, startIndex: syncIndex)
                syncIndex += artistParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = artistParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib version resync: %s Artists parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Albums
            }
            library.saveContext()
        }
        if syncWave.syncState == .Albums, isRunning {
            os_log("Lib version resync: Albums parsing start", log: log, type: .info)
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let albumParser = AlbumParserDelegate(library: library, syncWave: syncWave)
                ampacheXmlServerApi.requestAlbums(parserDelegate: albumParser, startIndex: syncIndex)
                syncIndex += albumParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = albumParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib version resync: %s Albums parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Done
            }
            library.saveContext()
        }
    }

}
