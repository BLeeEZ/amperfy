import Foundation
import UIKit
import CoreData

class SsArtistParserDelegate: SsXmlLibWithArtworkParser {

    private var artistBuffer: Artist?

    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        if elementName == "artist" {
            guard let artistId = attributeDict["id"] else { return }
            
            if let fetchedArtist = library.getArtist(id: artistId)  {
                artistBuffer = fetchedArtist
            } else {
                artistBuffer = library.createArtist()
                artistBuffer?.id = artistId
                artistBuffer?.syncInfo = syncWave
            }
            artistBuffer?.remoteStatus = .available
            if let attributeAlbumCount = attributeDict["albumCount"], let albumCount = Int(attributeAlbumCount) {
                artistBuffer?.albumCount = albumCount
            }

            if let attributeArtistName = attributeDict["name"] {
                artistBuffer?.name = attributeArtistName
            }
            if let attributeCoverArtId = attributeDict["coverArt"] {
                artistBuffer?.artwork = parseArtwork(id: attributeCoverArtId)
            }
            artistBuffer?.rating = Int(attributeDict["userRating"] ?? "0") ?? 0
		}    
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
		case "artist":
            parsedCount += 1
            artistBuffer = nil
		default:
			break
		}
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
