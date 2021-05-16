import Foundation
import os.log

class SsPingParserDelegate: SsXmlParser {
  
    var isAuthValid: Bool = false
    var serverApiVersion: String?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        switch(elementName) {
        case "subsonic-response":
            if let version = attributeDict["version"] {
                serverApiVersion = version
            }
        default:
            break
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "subsonic-response":
            if error == nil {
                isAuthValid = true
            }
            break
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
