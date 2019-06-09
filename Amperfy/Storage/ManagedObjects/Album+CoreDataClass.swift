import Foundation
import CoreData
import UIKit

@objc(Album)
public class Album: AbstractLibraryElementMO {

    override var identifier: String {
        return name ?? ""
    }
    
    override var image: UIImage {
        if super.image != Artwork.defaultImage {
            return super.image
        }
        if let artistArt = artist?.artwork?.image {
            return artistArt
        }
        return Artwork.defaultImage
    }
    
    var songsOfAlbum: [Song] {
        guard let songsSet = songs else { return [Song]() }
        return songsSet.array as! [Song]
    }
    
    var hasCachedSongs: Bool {
        for song in songsOfAlbum {
            if song.data != nil {
                return true
            }
        }
        return false
    }

}
