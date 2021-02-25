import Foundation
import os.log

class PingParserDelegate: GenericXmlParser {
  
    var isAuthValid: Bool = false
    var serverApiVersion: String?
    private var isErrorInResponse = false
    private var errorCode = ""
    private var errorMessage = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "subsonic-response":
            if let version = attributeDict["version"] {
                serverApiVersion = version
            }
        case "error":
            isErrorInResponse = true
            if let errorCode = attributeDict["code"], let errorMessage = attributeDict["message"] {
                self.errorCode = errorCode
                self.errorMessage = errorMessage
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
