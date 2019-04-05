import Foundation
import os.log

class PingParserDelegate: GenericXmlParser {
  
    var isAuthValid: Bool = false
    var responseVersion: String = ""
    private var isErrorInResponse = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "subsonic-response":
            if let version = attributeDict["version"] {
                responseVersion = version
            }
        case "error":
            isErrorInResponse = true
            if let errorCode = attributeDict["code"], let errorMessage = attributeDict["message"] {
                os_log("Error in ping response %s: %s", log: log, type: .error, errorCode, errorMessage)
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "subsonic-response":
            if !isErrorInResponse {
                isAuthValid = true
            }
            break
        default:
            break
        }
        
        buffer = ""
    }
    
}
