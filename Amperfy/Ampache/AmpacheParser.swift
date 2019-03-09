import Foundation
import os.log

class AmpacheParser: NSObject, XMLParserDelegate {
    
    let log = OSLog(subsystem: AppDelegate.name, category: "parser")
    var buffer = ""
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }
    
    func parseErrorOcurred(parser: XMLParser, error: NSError) {
        os_log("Error: %s", log: log, type: .error, error.localizedDescription)
    }
    
}

class AmpacheLibParser: AmpacheParser {
    
    var parsedCount = 0
    var libraryStorage: LibraryStorage
    var syncWave: SyncWaveMO
    var parseNotifier: ParsedObjectNotifiable?
    
    init(libraryStorage: LibraryStorage, syncWave: SyncWaveMO, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.libraryStorage = libraryStorage
        self.syncWave = syncWave
        self.parseNotifier = parseNotifier
    }
    
}
