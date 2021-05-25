import Foundation
import os.log

class SsMusicFolderParserDelegate: SsXmlParser {
    
    var musicFolders = [MusicFolder]()
        
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "musicFolder", let id = attributeDict["id"], let name = attributeDict["name"] {
            musicFolders.append( MusicFolder(id: id, name: name) )
        }

    }

}
