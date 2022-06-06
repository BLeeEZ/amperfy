import Foundation
import os.log

class GenericXmlParser: NSObject, XMLParserDelegate {
    
    static var debugPrint = false
    
    let log = OSLog(subsystem: "Amperfy", category: "Parser")
    var buffer = ""
    var parsedCount = 0
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }
    
    func parseErrorOcurred(parser: XMLParser, error: NSError) {
        os_log("Error: %s", log: log, type: .error, error.localizedDescription)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        if Self.debugPrint {
            os_log("<%s, %s>", log: log, type: .debug, elementName, attributeDict.description)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if Self.debugPrint {
            if !buffer.isEmpty {
                os_log("%s", log: log, type: .debug, buffer)
            }
            os_log("</%s>", log: log, type: .debug, elementName)
        }
        buffer = ""
    }
    
}
