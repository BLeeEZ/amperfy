//
//  SsPlayableParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 29.06.21.
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
import UIKit
import CoreData
import os.log

class SsPlayableParserDelegate: SsXmlLibWithArtworkParser {
    
    var playableBuffer: AbstractPlayable?
    
    override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        
        if elementName == "song" || elementName == "entry" || elementName == "child" || elementName == "episode" {
            guard let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir), isDirBool == false else { return }
            
            if let attributeTitle = attributeDict["title"] {
                playableBuffer?.title = attributeTitle
            }
            if let attributeTrack = attributeDict["track"], let track = Int(attributeTrack) {
                playableBuffer?.track = track
            }
            if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
                playableBuffer?.year = year
            }
            if let attributeDuration = attributeDict["duration"], let duration = Int(attributeDuration) {
                playableBuffer?.remoteDuration = duration
            }
            if let attributeSize = attributeDict["size"], let size = Int(attributeSize) {
                playableBuffer?.size = size
            }
            if let attributeBitrate = attributeDict["bitRate"], let bitrate = Int(attributeBitrate) {
                playableBuffer?.bitrate = bitrate * 1000 // kb per second -> save as byte per second
            }
            if let contentType = attributeDict["contentType"] {
                playableBuffer?.contentType = contentType
            }
            if let disk = attributeDict["discNumber"] {
                playableBuffer?.disk = disk
            }
            playableBuffer?.rating = Int(attributeDict["userRating"] ?? "0") ?? 0
            playableBuffer?.isFavorite = attributeDict["starred"] != nil
            if let coverArtId = attributeDict["coverArt"] {
                playableBuffer?.artwork = parseArtwork(id: coverArtId)
            }
        }
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "song" || elementName == "entry" || elementName == "child" || elementName == "episode", playableBuffer != nil {
            playableBuffer = nil
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
