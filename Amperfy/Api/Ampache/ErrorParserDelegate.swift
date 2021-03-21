import Foundation
import UIKit
import CoreData

class ErrorParserDelegate: GenericXmlParser {
    
    var error: ResponseError?
    private var statusCode: Int = 0
    private var message = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        switch(elementName) {
        case "error":
            statusCode = Int(attributeDict["code"] ?? "0") ?? 0
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "error":
            error = ResponseError(statusCode: statusCode, message: buffer)
        default:
            break
        }
        
        buffer = ""
    }
    
}
