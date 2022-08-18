//
//  GenreMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.04.21.
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
import CoreData

@objc(GenreMO)
public final class GenreMO: AbstractLibraryEntityMO {

}

extension GenreMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<GenreMO, String?> {
        return \GenreMO.name
    }
    
    func passOwnership(to targetGenre: GenreMO) {
        let artistsCopy = artists?.compactMap{ $0 as? ArtistMO }
        artistsCopy?.forEach{
            $0.genre = targetGenre
        }
        
        let albumsCopy = albums?.compactMap{ $0 as? AlbumMO }
        albumsCopy?.forEach{
            $0.genre = targetGenre
        }
        
        let songsCopy = songs?.compactMap{ $0 as? SongMO }
        songsCopy?.forEach{
            $0.genre = targetGenre
        }
    }
    
}
