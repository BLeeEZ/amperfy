//
//  SsXmlParser.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.05.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

class SsXmlParser: GenericXmlParser {
    
    var error: SubsonicResponseError?

    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if(elementName == "error") {
            let statusCode = Int(attributeDict["code"] ?? "0") ?? 0
            let message = attributeDict["message"] ?? ""
            error = SubsonicResponseError(statusCode: statusCode, message: message)
        }
    }
    
}

class SsNotifiableXmlParser: SsXmlParser {
    
    var parseNotifier: ParsedObjectNotifiable?
    
    init(parseNotifier: ParsedObjectNotifiable? = nil) {
        self.parseNotifier = parseNotifier
    }
    
}

class SsXmlLibParser: SsNotifiableXmlParser {
    
    var library: LibraryStorage
    
    init(library: LibraryStorage, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.library = library
        super.init(parseNotifier: parseNotifier)
    }
    
}

class SsXmlLibWithArtworkParser: SsXmlLibParser {
    
    var subsonicUrlCreator: SubsonicUrlCreator
    
    init(library: LibraryStorage, subsonicUrlCreator: SubsonicUrlCreator, parseNotifier: ParsedObjectNotifiable? = nil) {
        self.subsonicUrlCreator = subsonicUrlCreator
        super.init(library: library, parseNotifier: parseNotifier)
    }

    func parseArtwork(id: String) -> Artwork? {
        let remoteInfo = ArtworkRemoteInfo(id: id, type: "")
        if let foundArtwork = library.getArtwork(remoteInfo: remoteInfo) {
            return foundArtwork
        } else {
            let createdArtwork = library.createArtwork()
            createdArtwork.remoteInfo = remoteInfo
            createdArtwork.url = subsonicUrlCreator.getArtUrlString(forCoverArtId: id)
            return createdArtwork
        }
    }

}

