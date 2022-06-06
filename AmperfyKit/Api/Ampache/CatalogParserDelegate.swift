import Foundation
import UIKit
import CoreData
import os.log

class CatalogParserDelegate: AmpacheXmlLibParser {

    let musicFoldersBeforeFetch: Set<MusicFolder>
    var musicFoldersParsed = Set<MusicFolder>()
    var musicFolderBuffer: MusicFolder?

    init(library: LibraryStorage, syncWave: SyncWave) {
        musicFoldersBeforeFetch = Set(library.getMusicFolders())
        super.init(library: library, syncWave: syncWave)
    }
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        if(elementName == "catalog") {
            guard let id = attributeDict["id"] else {
                os_log("Found catalog with no id", log: log, type: .error)
                return
            }
            if let fetchedMusicFolder = library.getMusicFolder(id: id)  {
                musicFolderBuffer = fetchedMusicFolder
            } else {
                musicFolderBuffer = library.createMusicFolder()
                musicFolderBuffer?.id = id
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "name":
            musicFolderBuffer?.name = buffer
        case "catalog":
            parsedCount += 1
            if let parsedmusicFolder = musicFolderBuffer {
                musicFoldersParsed.insert(parsedmusicFolder)
            }
            musicFolderBuffer = nil
        case "root":
            let removedMusicFolders = musicFoldersBeforeFetch.subtracting(musicFoldersParsed)
            removedMusicFolders.forEach{ library.deleteMusicFolder(musicFolder: $0) }
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
