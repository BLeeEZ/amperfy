import Foundation
import os.log

class SsMusicFolderParserDelegate: SsXmlLibParser {
    
    let musicFoldersBeforeFetch: Set<MusicFolder>
    var musicFoldersParsed = Set<MusicFolder>()
    
    init(library: LibraryStorage, syncWave: SyncWave) {
        musicFoldersBeforeFetch = Set(library.getMusicFolders())
        super.init(library: library, syncWave: syncWave)
    }
        
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "musicFolder", let id = attributeDict["id"], let name = attributeDict["name"] {
            if let musicFolder = library.getMusicFolder(id: id) {
                musicFoldersParsed.insert(musicFolder)
            } else {
                let musicFolder = library.createMusicFolder()
                musicFolder.id = id
                musicFolder.name = name
                musicFoldersParsed.insert(musicFolder)
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "musicFolders" {
            let removedMusicFolders = musicFoldersBeforeFetch.subtracting(musicFoldersParsed)
            removedMusicFolders.forEach{ library.deleteMusicFolder(musicFolder: $0) }
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
