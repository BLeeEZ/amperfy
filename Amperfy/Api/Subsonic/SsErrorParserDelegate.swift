import Foundation
import os.log

class SsErrorParserDelegate: GenericXmlParser {
    
    var responseError: ResponseError?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        buffer = ""
        
        if(elementName == "error") {
            let statusCode = Int(attributeDict["code"] ?? "0") ?? 0
            let message = attributeDict["message"] ?? ""
            responseError = ResponseError(statusCode: statusCode, message: message)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        buffer = ""
    }
    
}
