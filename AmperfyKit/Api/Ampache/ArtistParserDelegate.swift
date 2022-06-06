import Foundation
import UIKit
import CoreData
import os.log

class ArtistParserDelegate: AmpacheXmlLibParser {

    var artistsParsed = Set<Artist>()
    var artistBuffer: Artist?
    var genreIdToCreate: String?
    var rating: Int = 0

    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        if elementName == "artist" {
            guard let artistId = attributeDict["id"] else {
                os_log("Found artist with no id", log: log, type: .error)
                return
            }
            if let fetchedArtist = library.getArtist(id: artistId)  {
                artistBuffer = fetchedArtist
            } else {
                artistBuffer = library.createArtist()
                artistBuffer?.syncInfo = syncWave
                artistBuffer?.id = artistId
            }
		}
        if elementName == "genre", let artist = artistBuffer {
            guard let genreId = attributeDict["id"] else { return }
            if let genre = library.getGenre(id: genreId) {
                artist.genre = genre
            } else {
                genreIdToCreate = genreId
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		switch(elementName) {
        case "name":
            artistBuffer?.name = buffer
		case "rating":
            rating = Int(buffer) ?? 0
        case "flag":
            let flag = Int(buffer) ?? 0
            artistBuffer?.isFavorite = flag == 1 ? true : false
        case "albumcount":
            artistBuffer?.albumCount = Int(buffer) ?? 0
        case "genre":
            if let genreId = genreIdToCreate {
                os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
                let genre = library.createGenre()
                genre.id = genreId
                genre.name = buffer
                genre.syncInfo = syncWave
                artistBuffer?.genre = genre
                genreIdToCreate = nil
            }
        case "art":
            artistBuffer?.artwork = parseArtwork(urlString: buffer)
		case "artist":
            parsedCount += 1
            parseNotifier?.notifyParsedObject(ofType: .artist)
            artistBuffer?.rating = rating
            rating = 0
            if let parsedArtist = artistBuffer {
                artistsParsed.insert(parsedArtist)
            }
            artistBuffer = nil
		default:
			break
		}
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
