import Foundation
import os.log

class SsMusicDirectoryParserDelegate: SsSongParserDelegate {
    
    var musicDirectories = [MusicDirectory]()
    var shortcuts = [MusicDirectory]()
    var songsInDirectory = [Song]()
        
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "child" {
            if let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir), isDirBool {
                if let id = attributeDict["id"], let parent = attributeDict["parent"], let title = attributeDict["title"] {
                    musicDirectories.append( MusicDirectory(id: id, parent: parent, name: title) )
                }
            } else if let song = songBuffer{
                songsInDirectory.append(song)
            }
        }
        if elementName == "artist" {
            if let id = attributeDict["id"], let name = attributeDict["name"] {
                musicDirectories.append( MusicDirectory(id: id, parent: "", name: name) )
            }
        }
        if elementName == "shortcut" {
            if let id = attributeDict["id"], let name = attributeDict["name"] {
                shortcuts.append( MusicDirectory(id: id, parent: "", name: name) )
            }
        }
    }

}
