import Foundation
import CoreData
import os.log

class AmpacheLibraryBackgroundSyncer: GenericLibraryBackgroundSyncer, BackgroundLibrarySyncer {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }

    func syncInBackground(library: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        
        if let latestSyncWave = library.getLatestSyncWave(), !latestSyncWave.isDone {
            os_log("Lib resync: Continue last resync", log: log, type: .info)
            resync(library: library, syncWave: latestSyncWave, previousAddDate: latestSyncWave.libraryChangeDates.dateOfLastAdd)
        } else if let latestSyncWave = library.getLatestSyncWave(),
        let ampacheMetaData = ampacheXmlServerApi.requesetLibraryMetaData(),
        latestSyncWave.libraryChangeDates.dateOfLastAdd != ampacheMetaData.libraryChangeDates.dateOfLastAdd {
            os_log("Lib resync: New changes on server", log: log, type: .info)
            let syncWave = library.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: ampacheMetaData.libraryChangeDates)
            library.saveContext()
            resync(library: library, syncWave: syncWave, previousAddDate: latestSyncWave.libraryChangeDates.dateOfLastAdd)
        } else {
            os_log("Lib resync: No changes", log: log, type: .info)
        }
        
        isActive = false
        semaphoreGroup.leave()
    }   
    
    private func resync(library: LibraryStorage, syncWave: SyncWave, previousAddDate: Date) {
        // Add one second to previouseAddDate to avoid resyncing previous sync Wave
        let addDate = Date(timeInterval: 1, since: previousAddDate)

        if syncWave.syncState == .Artists, isRunning {
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let artistParser = ArtistParserDelegate(library: library, syncWave: syncWave)
                ampacheXmlServerApi.requestArtists(parserDelegate: artistParser, addDate: addDate, startIndex: syncIndex, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                syncIndex += artistParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = artistParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib resync: %s Artists parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Albums
            }
            library.saveContext()
        }
        if syncWave.syncState == .Albums, isRunning {
            var allParsed = false
            repeat {
                var syncIndex = Int(syncWave.syncIndexToContinue) ?? 0
                let albumParser = AlbumParserDelegate(library: library, syncWave: syncWave)
                ampacheXmlServerApi.requestAlbums(parserDelegate: albumParser, addDate: addDate, startIndex: syncIndex, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                syncIndex += albumParser.parsedCount
                syncWave.syncIndexToContinue = String(syncIndex)
                allParsed = albumParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib resync: %s Albums parsed", log: log, type: .info, syncWave.syncIndexToContinue)
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
