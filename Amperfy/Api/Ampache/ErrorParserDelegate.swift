import Foundation
import UIKit
import CoreData

struct AmpacheXmlError {
    var code: Int = 0
    var message: String = ""
}

class ErrorParserDelegate: GenericXmlParser {
    
    var error: AmpacheXmlError? = nil
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "error":
            error = AmpacheXmlError()
            error?.code = Int(attributeDict["code"] ?? "0") ?? 0
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "error":
            error?.message = buffer
        default:
            break
        }
        
        buffer = ""
    }
    
}
