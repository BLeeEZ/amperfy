import Foundation
import CoreData
import os.log

class AmpacheLibraryVersionBackgroundResyncer: GenericLibraryBackgroundSyncer, BackgroundLibraryVersionResyncer {
   
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }

    func resyncDueToNewLibraryVersionInBackground(libraryStorage: LibraryStorage, libraryVersion: LibrarySyncVersion) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        
        if let latestSyncWave = libraryStorage.getLatestSyncWave(), latestSyncWave.syncType == .versionResync, latestSyncWave.version == libraryVersion , !latestSyncWave.isDone {
            os_log("Lib version resync: Continue update library version %s -> %s", log: log, type: .info, latestSyncWave.version.description, LibrarySyncVersion.newestVersion.description)
            resync(libraryStorage: libraryStorage, syncWave: latestSyncWave)
        } else {
            os_log("Lib version resync: Start update library version %s -> %s", log: log, type: .info, libraryVersion.description, LibrarySyncVersion.newestVersion.description)
            let syncWave = libraryStorage.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
            syncWave.version = libraryVersion
            syncWave.syncType = .versionResync
            libraryStorage.saveContext()
            resync(libraryStorage: libraryStorage, syncWave: syncWave)
        } 
        
        isActive = false
        semaphoreGroup.leave()
    }   
    
    private func resync(libraryStorage: LibraryStorage, syncWave: SyncWave) {
        if syncWave.syncState == .Artists, isRunning {
            os_log("Lib version resync: Artist parsing start", log: log, type: .info)
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let artistParser = ArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, ampacheUrlCreator: ampacheXmlServerApi)
                ampacheXmlServerApi.requestArtists(parserDelegate: artistParser, startIndex: syncIndex)
                syncIndex += artistParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = artistParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib version resync: %s Artists parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Albums
            }
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Albums, isRunning {
            os_log("Lib version resync: Albums parsing start", log: log, type: .info)
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let albumParser = AlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave)
                ampacheXmlServerApi.requestAlbums(parserDelegate: albumParser, startIndex: syncIndex)
                syncIndex += albumParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = albumParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib version resync: %s Albums parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Songs
            }
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Songs, isRunning {
            os_log("Lib version resync: Songs parsing start", log: log, type: .info)
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave)
                ampacheXmlServerApi.requestSongs(parserDelegate: songParser, startIndex: syncIndex)
                syncIndex += songParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = songParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib version resync: %s Songs parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Done
            }
            libraryStorage.saveContext()
        }
    }

}
