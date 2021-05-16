import Foundation
import os.log

class GenericXmlParser: NSObject, XMLParserDelegate {
    
    let log = OSLog(subsystem: AppDelegate.name, category: "Parser")
    var buffer = ""
    var parsedCount = 0
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }
    
    func parseErrorOcurred(parser: XMLParser, error: NSError) {
        os_log("Error: %s", log: log, type: .error, error.localizedDescription)
    }
    
}
